@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Root entity for Trip transaction'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_TripHeader
  as select from ztab_tripheader
  composition [0..*] of ZI_TripIncident as _Incident
  association [1] to zi_driver          as _Driver      on $projection.DriverID = _Driver.DriverId
  association [1] to ZI_Vehicle         as _Vehicle     on $projection.VehicleNumber = _Vehicle.VehicleRegNumber
  association [1] to ZI_LoadTypeVH      as _LoadTypeVH  on $projection.LoadType = _LoadTypeVH.LoadType
  association [1] to ZI_Location        as _Source      on $projection.SourceID = _Source.LocationID
  association [1] to ZI_Location        as _Destination on $projection.DestinationID = _Destination.LocationID
{
  key t_tripid                as TripID,
      t_cdate                 as TripDate,
      t_vno                   as VehicleNumber,
      t_driverid              as DriverID,
      t_sourceid              as SourceID,
      t_source                as StartPlace,
      t_destid                as DestinationID,
      t_destination           as EndPlace,
      t_loadtype              as LoadType,
      t_status                as TripStatus,
      
      t_currency      as Currency,
      t_weight_uom    as WeightUnit,
      @Semantics.amount.currencyCode: 'Currency'
      t_tot_exp       as TripTotalExpense,
      @Semantics.quantity.unitOfMeasure: 'WeightUnit'
      t_weight        as Weight,

      @Semantics.amount.currencyCode: 'Currency'
      t_rate_per_unit as RatePerUnit,

      @Semantics.amount.currencyCode: 'Currency'
      t_freight_amt   as FreightAmount,

      @Semantics.amount.currencyCode: 'Currency'
      t_comm_amt      as DriverCommission,

      @Semantics.amount.currencyCode: 'Currency'
      t_profit_amt    as NetProfit,
      
      t_review_reason         as ReviewReason,
      t_prev_status           as PreviousStatus,

      @Semantics.user.createdBy: true
      created_by              as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at              as CreateAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by         as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at         as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at   as LocalLastChangedAt,
      _LoadTypeVH.Description as LoadDescription,

      // Make association public
      _Incident,
      _Driver,
      _Vehicle,
      _LoadTypeVH,
      _Source,
      _Destination
}
