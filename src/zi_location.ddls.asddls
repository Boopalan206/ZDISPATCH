@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Location entity'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define root view entity ZI_Location
  as select from ztab_location
  //composition of target_data_source_name as _association_name
{
      @EndUserText.label: 'Location ID'
  key l_id       as LocationID,
  
      @EndUserText.label: 'Name'
      @Search.defaultSearchElement: true
      l_location as LocationName,
      
      @EndUserText.label: 'Company Name'
      l_company  as CompanyName
      //    _association_name // Make association public
}
