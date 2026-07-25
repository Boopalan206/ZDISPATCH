@EndUserText.label: 'Lockdown Reason Dialog'
define abstract entity ZA_LockdownReason
//  with parameters parameter_name : parameter_type
{
    @EndUserText.label: 'Reason for Lockdown'
    @UI.multiLineText: true
    review_reason : abap.string;
    
}
