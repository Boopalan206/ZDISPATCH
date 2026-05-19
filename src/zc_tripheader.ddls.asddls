@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumtion View - TripHeader'
@Metadata.allowExtensions: true
define root view entity ZC_TripHeader
  provider contract transactional_query
  as projection on ZI_TripHeader
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
      TripTotalExpense,
      ReviewReason,
      PreviousStatus,
      DriverName,
      DriverMobile,
      CreatedBy,
      CreateAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      LoadDescription,
      
      /* Associations */
      _Driver,
      _Incident : redirected to composition child ZC_TripIncident,
      _Vehicle,
      _LoadTypeVH,
      _Source,
      _Destination
      
}
