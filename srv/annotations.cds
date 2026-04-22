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
            { $Type: 'UI.DataField', Value: status, Label: 'Status', Criticality: statusCriticality },
            { $Type: 'UI.DataField', Value: createdAt, Label: 'Created At' }
        ],

        HeaderFacets: [
            {
                $Type: 'UI.ReferenceFacet',
                Target: '@UI.DataPoint#Status',
                ID: 'StatusHeaderFacet'
            },
            {
                $Type: 'UI.ReferenceFacet',
                Target: '@UI.DataPoint#TotalAmount',
                ID: 'TotalAmountHeaderFacet'
            }
        ],

        // Data Points for the Header Facets
        DataPoint#Status: {
            Value: status,
            Title: 'Current Status',
            Criticality: statusCriticality
        },
        DataPoint#TotalAmount: {
            Value: totalAmount,
            Title: 'Total Value'
        },

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
                // { $Type: 'UI.DataField', Value: status, Label: 'Status' },
                // { $Type: 'UI.DataField', Value: totalAmount, Label: 'Total Amount' },
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
        LineItem: [
            { $Type: 'UI.DataField', Value: materialName, Label: 'Material' },
            { $Type: 'UI.DataField', Value: vendorName, Label: 'Vendor' },
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

    status @(
        Common.ValueListWithFixedValues: true
    );
};

annotate MMService.PR_Items with {
    ID @UI.Hidden;

    material_ID @(
        Common.Text            : materialName,
        Common.TextArrangement : #TextOnly,
        Common.ValueList       : {
            Label          : 'Materials',
            CollectionPath : 'Materials',
            Parameters     : [
                { $Type : 'Common.ValueListParameterInOut', LocalDataProperty : material_ID, ValueListProperty : 'ID' },
                { $Type : 'Common.ValueListParameterDisplayOnly', ValueListProperty : 'name' }
            ]
        }
    );

    vendor_ID @(
        Common.Text            : vendorName,
        Common.TextArrangement : #TextOnly,
        Common.ValueList       : {
            Label          : 'Vendors',
            CollectionPath : 'Vendors',
            Parameters     : [
                { $Type : 'Common.ValueListParameterInOut', LocalDataProperty : vendor_ID, ValueListProperty : 'ID' },
                { $Type : 'Common.ValueListParameterDisplayOnly', ValueListProperty : 'name' }
            ]
        }
    );
};