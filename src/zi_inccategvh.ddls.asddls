@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Category Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_IncCategVH
    as select from DDCDS_CUSTOMER_DOMAIN_VALUE(
                      p_domain_name : 'ZD_INC_CATG') as Values
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T(
                      p_domain_name : 'ZD_INC_CATG') as Texts
      on  Texts.domain_name    = Values.domain_name
      and Texts.value_position = Values.value_position
      and Texts.language       = $session.system_language
{
      @EndUserText.label: 'Category'
      @Search.defaultSearchElement: true
  key Values.value_low as Category,
  
      Texts.text       as Description
}
