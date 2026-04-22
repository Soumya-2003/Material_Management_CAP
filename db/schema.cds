namespace mm.app;

using {mm.common.UserRole} from './common';
// using {mm.common.PRStatus} from './common';
using {mm.common.POStatus} from './common';
using {mm.common.GRStatus} from './common';

entity Users {
    key ID                    : UUID;
        userId                : String(10);
        name                  : String(100);
        email                 : String(100);
        role                  : UserRole;
        managerId             : Association to Users;
        department            : String(50);
        vendorRatingThreshold : Integer;
}

entity Materials {
    key ID          : UUID;
        name        : String(100);
        description : String(255);
        unit        : String(10);
        price       : Decimal(15, 2);
        isActive    : Boolean default true;
}

entity Vendors {
    key ID        : UUID;
        name      : String(100);
        email     : String(100);
        rating    : Integer;
        isActive  : Boolean default true;
        materials : Composition of many VendorMaterials
                        on materials.vendor = $self;
}

entity VendorMaterials {
    key ID       : UUID;
        vendor   : Association to Vendors;
        material : Association to Materials;
}

entity DraftPurchaseRequisitions {
    key ID        : UUID;
    prNumber      : String(20);
    material_ID   : UUID;
    vendor_ID     : UUID;
    quantity      : Integer;
    totalAmount   : Decimal(15,2);
    status        : String default 'DRAFT';
    createdAt     : Timestamp;
}

entity PurchaseRequisitions {
    key ID        : UUID;
    prNumber      : String;
    status        : String;
    totalAmount   : Decimal(15,2);
    createdAt     : Timestamp;
    items       : Composition of many PR_Items
                          on items.pr = $self;
}

entity PR_Items {
    key ID        : UUID;
    pr            : Association to PurchaseRequisitions;
    material  : Association to Materials;
    vendor    : Association to Vendors;
    quantity      : Integer;
    price     : Decimal(15, 2);
}

entity PurchaseOrders {
    key ID          : UUID;
        poNumber    : String(20);
        pr          : Association to PurchaseRequisitions;
        vendor      : Association to Vendors;
        status      : POStatus default 'CREATED';
        totalAmount : Decimal(15, 2);
        createdAt   : Timestamp;
        items       : Composition of many PO_Items
                          on items.parent = $self;
}

entity PO_Items {
    key ID       : UUID;
        parent   : Association to PurchaseOrders;
        material : Association to Materials;
        quantity : Integer;
        price    : Decimal(15, 2);
}

entity GoodsReceipts {
    key ID       : UUID;
        po       : Association to PurchaseOrders;
        status   : GRStatus default 'PENDING';
        postedAt : Timestamp;
        items    : Composition of many GR_Items
                       on items.parent = $self;
}

entity GR_Items {
    key ID       : UUID;
        parent   : Association to GoodsReceipts;
        material : Association to Materials;
        quantity : Integer;
}

entity Stocks {
    key ID       : UUID;
        material : Association to Materials;
        quantity : Integer;
}
