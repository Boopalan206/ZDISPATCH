@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Vehicle entity'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define root view entity ZI_Vehicle
  as select from ztab_vehicle
  //composition of target_data_source_name as _association_name
{
      @EndUserText.label: 'Vehicle Number'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
  key v_reg_no   as VehicleRegNumber,
  
      @EndUserText.label: 'Model'
      @Search.defaultSearchElement: true
      v_model    as VehicleModel,
      
      @EndUserText.label: 'Capacity'
      v_capacity as VehicleCapacity,
      
      
      @EndUserText.label: 'Status'
      v_status   as VehicleStatus,
      
      @EndUserText.label: 'Driver ID'
      d_id       as AssignedDriverID
      //    _association_name // Make association public
}
