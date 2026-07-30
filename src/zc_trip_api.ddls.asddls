@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API for Trip'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_Trip_API 
provider contract transactional_query
as projection on ZI_TRIPHEADER
{
    key TripID,
    TripDate,
    VehicleNumber,
    DriverID,
     @ObjectModel.text.element: [ 'StartPlace' ]
    SourceID,
    StartPlace,
    
    @ObjectModel.text.element: [ 'EndPlace' ]
    DestinationID,
    EndPlace,
    
    @ObjectModel.text.element: [ 'LoadDescription' ]
    LoadType,
    TripStatus,
    Currency,
    WeightUnit,
    @Semantics.amount.currencyCode: 'Currency'
    TripTotalExpense,
    @Semantics.quantity.unitOfMeasure: 'WeightUnit'
    Weight,
    
    @Semantics.amount.currencyCode: 'Currency'
    RatePerUnit,
    
    @Semantics.amount.currencyCode: 'Currency'
    FreightAmount,
    
    @Semantics.amount.currencyCode: 'Currency'
    DriverCommission,
    
    @Semantics.amount.currencyCode: 'Currency'
    NetProfit,
    ReviewReason,
    PreviousStatus,
    CreatedBy,
    CreateAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    LoadDescription,
    /* Associations */
    _Destination,
    _Driver,
    _Incident : redirected to composition child ZC_Incident_API,
    _LoadTypeVH,
    _Source,
    _Vehicle
}
