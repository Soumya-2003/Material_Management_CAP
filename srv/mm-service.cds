using {mm.app as db} from '../db/schema';

service MMService @(requires: 'any') {

    entity DraftPurchaseRequisitions as projection on db.DraftPurchaseRequisitions;
    entity DraftPR_Items as projection on db.DraftPR_Items;

    entity PurchaseRequisitions      as
        projection on db.PurchaseRequisitions {
            *,
            virtual 0 as statusCriticality : Integer
        };

    entity PR_Items                  as
        projection on db.PR_Items {
            *,
            material.name as materialName : String,
            vendor.name   as vendorName   : String,
            virtual 0     as statusCriticality : Integer
        };

    entity PurchaseOrders            as projection on db.PurchaseOrders;
    entity PO_Items                  as projection on db.PO_Items;
    entity GoodsReceipts             as projection on db.GoodsReceipts;
    entity GR_Items                  as projection on db.GR_Items;
    entity Stocks                    as projection on db.Stocks;

    entity Materials                 as projection on db.Materials;
    entity Vendors                   as projection on db.Vendors;
    entity VendorMaterials           as projection on db.VendorMaterials;

    type DraftItemInput {
        material_ID : UUID;
        vendor_ID   : UUID;
        quantity    : Integer;
    }

    action saveDraft(ID: UUID, items: array of DraftItemInput) returns UUID;
    action submitDraft(draftID: UUID)                                                 returns UUID;
    action createDraft()                                                              returns DraftPurchaseRequisitions;

    action approvePRItem(itemID: UUID) returns String;
    action rejectPRItem(itemID: UUID, reason: String) returns String;
    action editRejectedItem(itemID: UUID) returns UUID;

    action acceptPO(poID: UUID) returns String;
}
