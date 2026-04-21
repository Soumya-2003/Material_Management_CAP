const cds = require('@sap/cds');
const { executeHttpRequest } = require('@sap-cloud-sdk/http-client');

module.exports = cds.service.impl(async function () {

    const {
        DraftPurchaseRequisitions,
        PurchaseRequisitions,
        PR_Items,
        PurchaseOrders,
        PO_Items,
        Materials,
        Vendors
    } = this.entities;

    this.on('saveDraft', async (req) => {
        const { ID, material_ID, vendor_ID, quantity } = req.data;
        let totalAmount = 0;
       
        if (material_ID) {
            const material = await SELECT.one.from(Materials).where({ ID: material_ID });
            if (material) {
                totalAmount = (quantity || 0) * material.price;
            }
        }

        await UPDATE(DraftPurchaseRequisitions).set({
            material_ID,
            vendor_ID,
            quantity,
            totalAmount
        }).where({ ID });;

        return ID;
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
        if (!draft) req.error(404, "Draft not found");

        const material = await SELECT.one.from(Materials).where({ ID: draft.material_ID });
        const vendor = await SELECT.one.from(Vendors).where({ ID: draft.vendor_ID });
        const vendorRating = vendor ? vendor.rating : 3;

        const prID = cds.utils.uuid();
        
        await INSERT.into(PurchaseRequisitions).entries({
            ID: prID,
            prNumber: draft.prNumber,
            status: 'IN_APPROVAL',
            totalAmount: draft.totalAmount,
            createdAt: new Date().toISOString()
        });

        await INSERT.into(PR_Items).entries({
            ID: cds.utils.uuid(),
            pr_ID: prID,
            material_ID: draft.material_ID,
            vendor_ID: draft.vendor_ID,
            quantity: draft.quantity,
            price: material.price 
        });

        await DELETE.from(DraftPurchaseRequisitions).where({ ID: draftID });

        await triggerWorkflow({
            prID: prID,
            prNumber: draft.prNumber,
            requester: 'EMP001',
            manager: 'MGR001',
            vendorRating: parseInt(vendorRating, 10) || 0,
            totalAmount: parseFloat(draft.totalAmount) || 0
        });

        return prID;
    });

    this.on('approvePR', async (req) => {
        const { prID } = req.data;
        const pr = await SELECT.one.from(PurchaseRequisitions).where({ ID: prID });
        
        if (!pr || pr.status !== 'IN_APPROVAL') req.error(400, 'PR not found or not in approval state');
        
        // 1. Update PR Status
        await UPDATE(PurchaseRequisitions).set({ status: 'APPROVED' }).where({ ID: prID });

        // 2. Auto Create Purchase Order
        await createPOFromPR(prID);
        
        return 'PR Approved & PO Created';
    });

    this.on('rejectPR', async (req) => {
        const { prID } = req.data;
        await UPDATE(PurchaseRequisitions).set({ status: 'REJECTED' }).where({ ID: prID });
        return 'PR Rejected';
    });


    async function createPOFromPR(prID) {
        const pr = await SELECT.one.from(PurchaseRequisitions).where({ ID: prID });
        
        const items = await SELECT.from(PR_Items).where({ pr_ID: prID });
        if (!items || items.length === 0) return;
        
        const prItem = items; 
        const poID = cds.utils.uuid();

        // 1. Create PO Header
        await INSERT.into(PurchaseOrders).entries({
            ID: poID,
            poNumber: 'PO-' + Date.now(), 
            pr_ID: prID,
            vendor_ID: prItem.vendor_ID,
            status: 'CREATED',
            totalAmount: pr.totalAmount,
            createdAt: new Date().toISOString()
        });

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
            console.log('Calling BPA Workflow for PR:', payload.prNumber);
            await executeHttpRequest(
                { destinationName: 'bpaWorkflow-destination' }, 
                {
                    method: 'POST',
                    url: '/workflow/rest/v1/workflow-instances',
                    data: {
                        definitionId: 'us10.65d203eetrial.materialmanagementprworkflow1.pRApprovalProcess', 
                        context: {
                            prid: payload.prID,
                            prnumber: payload.prNumber,
                            requester: payload.requester,
                            manager: payload.manager,
                            vendorrating: payload.vendorRating,
                            totalamount: payload.totalAmount
                        }
                    }
                }
            );
            console.log('Workflow triggered successfully!');
        } catch (error) {
            console.error('Workflow trigger failed:', error.message);
        }
    }
});