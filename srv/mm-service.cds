using {mm.app as db} from '../db/schema';

service MMService @(requires: 'any') {

    entity DraftPurchaseRequisitions as projection on db.DraftPurchaseRequisitions;
    entity PurchaseRequisitions      as projection on db.PurchaseRequisitions;
    entity PR_Items                  as projection on db.PR_Items;

    entity PurchaseOrders            as projection on db.PurchaseOrders;
    entity PO_Items                  as projection on db.PO_Items;
    entity GoodsReceipts             as projection on db.GoodsReceipts;
    entity GR_Items                  as projection on db.GR_Items;
    entity Stocks                    as projection on db.Stocks;

    entity Materials                 as projection on db.Materials;
    entity Vendors                   as projection on db.Vendors;
    entity VendorMaterials           as projection on db.VendorMaterials;

    action saveDraft(ID: UUID, material_ID: UUID, vendor_ID: UUID, quantity: Integer) returns UUID;
    action submitDraft(draftID: UUID) returns UUID;
    action createDraft() returns DraftPurchaseRequisitions;

    action approvePR(prID: UUID) returns String;
    action rejectPR(prID: UUID, reason: String) returns String;
}
