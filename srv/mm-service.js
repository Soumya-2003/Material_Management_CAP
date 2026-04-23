const cds = require('@sap/cds');
const { executeHttpRequest } = require('@sap-cloud-sdk/http-client');

module.exports = cds.service.impl(async function () {

    const {
        DraftPurchaseRequisitions,
        DraftPR_Items,
        PurchaseRequisitions,
        PR_Items,
        PurchaseOrders,
        PO_Items,
        Materials,
        Vendors,
        GoodsReceipts,
        GR_Items,
        Stocks
    } = this.entities;

    this.after('READ', [PurchaseRequisitions, PR_Items], each => {
        if (!each.status) return; // Skip if status wasn't requested in the query
        
        switch (each.status) {
            case 'APPROVED':
            case 'COMPLETED':
                each.statusCriticality = 3; // 3 = Green
                break;
            case 'REJECTED':
                each.statusCriticality = 1; // 1 = Red
                break;
            case 'IN_APPROVAL':
            case 'PARTIALLY_APPROVED':
                each.statusCriticality = 2; // 2 = Orange
                break;
            case 'DRAFT':
            default:
                each.statusCriticality = 0; // 0 = Grey
                break;
        }
    });

    this.on('saveDraft', async (req) => {
        try {
            const { ID, items } = req.data;
            let totalAmount = 0;
           
            // 1. Clear out the old cart items
            await DELETE.from(DraftPR_Items).where({ draft_ID: ID });

            const newItems = [];
            for (let item of (items || [])) {
                const material = await SELECT.one.from(Materials).where({ ID: item.material_ID });
                let price = material ? material.price : 0;
                totalAmount += (item.quantity * price);

                newItems.push({
                    ID: cds.utils.uuid(),
                    draft_ID: ID,
                    material_ID: item.material_ID, 
                    vendor_ID: item.vendor_ID,     
                    quantity: item.quantity,
                    price: price
                });
            }

            // 2. Insert the new cart items
            if (newItems.length > 0) {
                await INSERT.into(DraftPR_Items).entries(newItems);
            }

            // 3. Update the Header
            await UPDATE(DraftPurchaseRequisitions).set({ totalAmount }).where({ ID });

            return ID;

        } catch (error) {
            // This prevents the 502 Server Crash!
            console.error("!!! CAP Server Error in saveDraft !!!", error);
            return req.error(500, "Backend failed to save draft: " + error.message);
        }
    });

    this.on('createDraft', async () => {
        try {
            console.log("createDraft action triggered");

            const ID = cds.utils.uuid();
            const prNumber = 'PR-' + Date.now();

            const entry = {
                ID: ID,
                prNumber: prNumber,
                quantity: 0,
                totalAmount: 0,
                status: 'DRAFT',
                createdAt: new Date().toISOString()
            };

            console.log("Attempting to insert into DraftPurchaseRequisitions:", entry);

            await INSERT.into(DraftPurchaseRequisitions).entries(entry);

            console.log("Insert successful!");

            return entry;

        } catch (error) {
            console.error("!!! CAP Server Error in createDraft !!!", error);
            req.error(500, "Backend failed to create draft in database.");
        }
    });

    this.on('submitDraft', async (req) => {
        const { draftID } = req.data;

        const draft = await SELECT.one.from(DraftPurchaseRequisitions).where({ ID: draftID });
        const draftItems = await SELECT.from(DraftPR_Items).where({ draft_ID: draftID });
        if (!draft) req.error(404, "Draft not found");

        const prID = cds.utils.uuid();        
        
        await INSERT.into(PurchaseRequisitions).entries({
            ID: prID,
            prNumber: draft.prNumber,
            status: 'IN_APPROVAL',
            totalAmount: draft.totalAmount,
            createdAt: new Date().toISOString()
        });

        const prItemsToInsert = draftItems.map(item => ({
            ID: cds.utils.uuid(),
            pr_ID: prID,
            material_ID: item.material_ID,
            vendor_ID: item.vendor_ID,
            quantity: item.quantity,
            price: item.price,
            status: 'IN_APPROVAL'
        }));

        if (prItemsToInsert.length > 0) {
            await INSERT.into(PR_Items).entries(prItemsToInsert);

            for (const item of prItemsToInsert) {
                // Fetch names for the manager to see in the BPA Form
                const mat = await SELECT.one.from(Materials).where({ ID: item.material_ID });
                const ven = await SELECT.one.from(Vendors).where({ ID: item.vendor_ID });

                await triggerWorkflow({
                    itemID: item.ID,
                    prNumber: draft.prNumber,
                    materialName: mat ? mat.name : 'Unknown Material',
                    vendorName: ven ? ven.name : 'Unknown Vendor',
                    vendorRating: ven ? ven.rating : 0,
                    quantity: item.quantity,
                    itemTotal: item.quantity * item.price,
                    requester: req.user.id || 'EMP001'
                });
            }
        }

        await DELETE.from(DraftPR_Items).where({ draft_ID: draftID });
        await DELETE.from(DraftPurchaseRequisitions).where({ ID: draftID });

        return prID;
    });

    this.on('approvePRItem', async (req) => {
        const { itemID } = req.data;
        const item = await SELECT.one.from(PR_Items).where({ ID: itemID });
        if (!item || item.status !== 'IN_APPROVAL') req.error(400, 'Item not found or not in approval state');

        // 1. Update PR Status
        await UPDATE(PR_Items).set({ status: 'APPROVED' }).where({ ID: itemID });

        // 2. Auto Create Purchase Order
        await createPOFromPRItem(itemID);

        await syncPRHeaderStatus(itemID);
        
        return 'Item Approved & PO Processed';
    });

    this.on('rejectPRItem', async (req) => {
        const { itemID, reason } = req.data;
        
        // 1. Update the specific item to REJECTED
        await UPDATE(PR_Items).set({ status: 'REJECTED' }).where({ ID: itemID });
        
        // 2. (Optional) You might want to log the reason somewhere, or just return it
        console.log(`Item ${itemID} rejected. Reason: ${reason}`);

        // 3. Sync the header status (see point 2 below)
        await syncPRHeaderStatus(itemID);

        return 'Item Rejected';
    });


    async function createPOFromPRItem(itemID) {
        const prItem = await SELECT.one.from(PR_Items).where({ ID: itemID });
        const pr = await SELECT.one.from(PurchaseRequisitions).where({ ID: prItem.pr_ID });
        
        let existingPO = await SELECT.one.from(PurchaseOrders).where({ 
            pr_ID: pr.ID, 
            vendor_ID: prItem.vendor_ID 
        });

        let poID;
        let itemTotal = prItem.quantity * prItem.price;
        
        if (existingPO) {
            poID = existingPO.ID;
            await UPDATE(PurchaseOrders)
                .set({ totalAmount: existingPO.totalAmount + itemTotal })
                .where({ ID: poID });
        } else {
            poID = cds.utils.uuid();
            await INSERT.into(PurchaseOrders).entries({
                ID: poID,
                poNumber: 'PO-' + Date.now() + '-' + Math.floor(Math.random() * 100),  
                pr_ID: pr.ID,
                vendor_ID: prItem.vendor_ID,
                status: 'CREATED',
                totalAmount: itemTotal,
                createdAt: new Date().toISOString()
            });
        }

        // 2. Create single PO Item (strictly 1-to-1)
        await INSERT.into(PO_Items).entries({
            ID: cds.utils.uuid(),
            parent_ID: poID,
            material_ID: prItem.material_ID,
            quantity: prItem.quantity,
            price: prItem.price
        });
    }

    async function triggerWorkflow(payload) {
        try {
            console.log('Calling BPA Workflow for PR:', payload.itemID);
            await executeHttpRequest(
                { destinationName: 'bpaWorkflow-destination' }, 
                {
                    method: 'POST',
                    url: '/workflow/rest/v1/workflow-instances',
                    data: {
                        definitionId: 'us10.65d203eetrial.mmprapproval.pRApprovalProcess', 
                        context: {
                            item_id: payload.itemID,
                            pr_number: payload.prNumber,
                            material_name: payload.materialName,
                            vendor_name: payload.vendorName,
                            vendor_rating: payload.vendorRating,
                            quantity: payload.quantity,
                            item_total: payload.itemTotal,
                            requester: payload.requester
                        }      
                    }
                }
            );
            console.log('Workflow triggered successfully for item!');
        } catch (error) {
            console.error('Workflow trigger failed:', error.message);
        }
    }

    this.on('acceptPO', async (req) => {
        try {
            const { poID } = req.data;
            if (!poID) return req.error(400, 'PO ID is missing');

            // 1. Fetch the PO
            const po = await SELECT.one.from(PurchaseOrders).where({ ID: poID });
            if (!po) return req.error(404, 'PO not found');
            
            // 2. Fetch PO Items
            const poItems = await SELECT.from(PO_Items).where({ parent_ID: poID });
            if (!poItems || poItems.length === 0) return req.error(400, 'No items in PO');

            // 3. Update PO Status 
            // Note: If 'COMPLETED' is not in your POStatus enum in common.cds, this will fail!
            await UPDATE(PurchaseOrders).set({ status: 'COMPLETED' }).where({ ID: poID });

            // 4. Create Goods Receipt Header
            const grID = cds.utils.uuid();
            await INSERT.into(GoodsReceipts).entries({
                ID: grID,
                po_ID: poID,
                status: 'POSTED', // Note: Check if 'POSTED' is in your GRStatus enum!
                postedAt: new Date().toISOString()
            });

            // 5. Process Items & Update Stock
            for (const item of poItems) {
                // Create GR Item
                await INSERT.into(GR_Items).entries({
                    ID: cds.utils.uuid(),
                    parent_ID: grID,
                    material_ID: item.material_ID,
                    quantity: item.quantity || 0
                });

                // Update or Create Stock
                const stock = await SELECT.one.from(Stocks).where({ material_ID: item.material_ID });
                
                if (stock) {
                    // Safe math to prevent null crashing
                    const currentQty = stock.quantity || 0;
                    const addedQty = item.quantity || 0;

                    await UPDATE(Stocks)
                        .set({ quantity: currentQty + addedQty })
                        .where({ material_ID: item.material_ID });
                } else {
                    await INSERT.into(Stocks).entries({
                        ID: cds.utils.uuid(),
                        material_ID: item.material_ID,
                        quantity: item.quantity || 0
                    });
                }
            }

            return 'PO Accepted, Goods Receipt Generated, and Stock Updated!';

        } catch (error) {
            // This prevents the 502 Server Crash!
            console.error("!!! CAP Server Error in acceptPO !!!", error);
            return req.error(500, "Backend failed: " + error.message);
        }
    });

    // Add this helper function at the bottom of mm-service.js
    async function syncPRHeaderStatus(itemID) {
        // Find which PR this item belongs to
        const prItem = await SELECT.one.from(PR_Items).where({ ID: itemID });
        if (!prItem) return;

        const prID = prItem.pr_ID;

        // Fetch all items for this PR
        const allItems = await SELECT.from(PR_Items).where({ pr_ID: prID });
        
        const totalItems = allItems.length;
        const approvedItems = allItems.filter(i => i.status === 'APPROVED').length;
        const rejectedItems = allItems.filter(i => i.status === 'REJECTED').length;

        let newHeaderStatus = 'IN_APPROVAL';

        // If every single item has been acted upon (none left in IN_APPROVAL)
        if (approvedItems + rejectedItems === totalItems) {
            if (approvedItems === totalItems) {
                newHeaderStatus = 'APPROVED'; // All good
            } else if (rejectedItems === totalItems) {
                newHeaderStatus = 'REJECTED'; // All bad
            } else {
                newHeaderStatus = 'PARTIALLY_APPROVED'; // Mix of both
            }
            
            // Update the header
            await UPDATE(PurchaseRequisitions).set({ status: newHeaderStatus }).where({ ID: prID });
        }
    }
});