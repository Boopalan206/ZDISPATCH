@EndUserText.label: 'Abstract entity for location details'
define abstract entity za_location
//  with parameters parameter_name : parameter_type
{
    @EndUserText.label: 'Location Name'
    loc_name : abap.char(30);
    
    @EndUserText.label: 'Company Name'
    comp_name : abap.char(50);
}
