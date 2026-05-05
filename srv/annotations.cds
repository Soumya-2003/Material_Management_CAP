using MMService from './mm-service';

annotate MMService.PurchaseRequisitions with @(
    UI: {
        HeaderInfo: {
            TypeName: 'Purchase Requisition',
            TypeNamePlural: 'Purchase Requisitions',
            Title: { $Type: 'UI.DataField', Value: prNumber },
            Description: { $Type: 'UI.DataField', Value: status }
        },
        
        SelectionFields: [
            prNumber,
            status
        ],

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

        DataPoint#Status: {
            Value: status,
            Title: 'Current Status',
            Criticality: statusCriticality
        },
        DataPoint#TotalAmount: {
            Value: totalAmount,
            Title: 'Total Value'
        },

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

        FieldGroup#GeneralInfo: {
            Data: [
                { $Type: 'UI.DataField', Value: prNumber, Label: 'PR Number' },
                { $Type: 'UI.DataField', Value: createdAt, Label: 'Created At' }
            ]
        }
    }
);


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