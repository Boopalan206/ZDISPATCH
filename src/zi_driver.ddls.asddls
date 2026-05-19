@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for driver'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define root view entity zi_driver
  as select from ztab_driver
{
      @EndUserText.label: 'ID'
  key d_id        as DriverId,
  
      @EndUserText.label: 'Name'
      @Search.defaultSearchElement: true
      d_full_name as FullName,
      
      @EndUserText.label: 'Phone'
      d_mobile    as Mobile,
      
      @EndUserText.label: 'Emergency'
      d_emobile   as Emergencymobile,
      
      @EndUserText.label: 'License'
      d_license   as DrivingLicense,
      
      @EndUserText.label: 'Expiry'
      d_lexpiry   as LicenseExpiry,
      
      @EndUserText.label: 'Govt.ID'
      d_govid     as GovernmentID,
      
      @EndUserText.label: 'Aadhar'
      d_aadhar    as AadharCard,
      
      @EndUserText.label: 'PAN Card'
      d_pan       as PanCard,
      
      @EndUserText.label: 'Status'
      d_status    as DriverStatus
}
