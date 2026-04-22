using MMService from './mm-service';

// ---------------------------------------------------------------------------
// Annotations for Purchase Requisitions (Header)
// ---------------------------------------------------------------------------
annotate MMService.PurchaseRequisitions with @(
    UI: {
        HeaderInfo: {
            TypeName: 'Purchase Requisition',
            TypeNamePlural: 'Purchase Requisitions',
            Title: { $Type: 'UI.DataField', Value: prNumber },
            Description: { $Type: 'UI.DataField', Value: status }
        },
        
        // Fields to show in the Filter Bar at the top of the List Report
        SelectionFields: [
            prNumber,
            status
        ],

        // Columns to show in the List Report table (No Action Buttons)
        LineItem: [
            { $Type: 'UI.DataField', Value: prNumber, Label: 'PR Number' },
            { $Type: 'UI.DataField', Value: totalAmount, Label: 'Total Amount' },
            { $Type: 'UI.DataField', Value: status, Label: 'Status' },
            { $Type: 'UI.DataField', Value: createdAt, Label: 'Created At' }
        ],

        // Object Page Layout (Facets)
        Facets: [
            {
                $Type: 'UI.ReferenceFacet',
                ID: 'GeneralInfoFacet',
                Label: 'General Information',
                Target: '@UI.FieldGroup#GeneralInfo'
            },
            {
                $Type: 'UI.ReferenceFacet',
                ID: 'ItemsFacet',
                Label: 'Requisition Items',
                Target: 'items/@UI.LineItem'
            }
        ],

        // Data fields for the General Information section on the Object Page
        FieldGroup#GeneralInfo: {
            Data: [
                { $Type: 'UI.DataField', Value: prNumber, Label: 'PR Number' },
                { $Type: 'UI.DataField', Value: status, Label: 'Status' },
                { $Type: 'UI.DataField', Value: totalAmount, Label: 'Total Amount' },
                { $Type: 'UI.DataField', Value: createdAt, Label: 'Created At' }
            ]
        }
    }
);

// ---------------------------------------------------------------------------
// Annotations for Purchase Requisition Items (Lines)
// ---------------------------------------------------------------------------
annotate MMService.PR_Items with @(
    UI: {
        // Columns for the Items table on the Object Page
        LineItem: [
            { $Type: 'UI.DataField', Value: material_ID, Label: 'Material ID' },
            { $Type: 'UI.DataField', Value: vendor_ID, Label: 'Vendor ID' },
            { $Type: 'UI.DataField', Value: quantity, Label: 'Quantity' },
            { $Type: 'UI.DataField', Value: price, Label: 'Unit Price' }
        ]
    }
);

// ---------------------------------------------------------------------------
// Field Formatting and Value Helps (Optional but Recommended)
// ---------------------------------------------------------------------------
annotate MMService.PurchaseRequisitions with {
    ID @UI.Hidden;
    prNumber @readonly;
    createdAt @readonly;
    totalAmount @readonly;
};

annotate MMService.PR_Items with {
    ID @UI.Hidden;
};