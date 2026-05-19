@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value help for load type'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_LoadTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE(
                      p_domain_name : 'ZD_LOADTYPE') as Values
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T(
                      p_domain_name : 'ZD_LOADTYPE') as Texts
      on  Texts.domain_name    = Values.domain_name
      and Texts.value_position = Values.value_position
      and Texts.language       = $session.system_language
{
      @EndUserText.label: 'Load Type'
  key Values.value_low as LoadType,
  
      @Search.defaultSearchElement: true
      Texts.text       as Description
}
