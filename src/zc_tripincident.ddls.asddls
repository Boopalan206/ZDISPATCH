@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trip Incident Consumption'
@Metadata.allowExtensions: true
define view entity ZC_TripIncident
  as projection on ZI_TripIncident
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
      _Currency,
      _TripHeader : redirected to parent ZC_TripHeader,
      _IAttachment : redirected to composition child ZC_INC_ATT1,
      _Categories
}
