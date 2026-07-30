@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API for Incident'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_Incident_API 

as projection on ZI_TRIPINCIDENT
{
    key IncidentID,
    key TripID,
    IncidentDate,
    @ObjectModel.text.element: [ 'CategoryDescription' ]
    IncidentCategory,
    IncidentDescription,
    IncidentLocation,
    @Semantics.amount.currencyCode: 'Currency'
    IncidentAmount,
    Currency,
    ReceiptStatus,
    IncidentCreatedBy,
    CreateAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    CategoryDescription,
    /* Associations */
    _Categories,
    _Currency,
    _IAttachment: redirected to composition child ZC_Attach_API,
    _TripHeader : redirected to parent ZC_Trip_API
}
