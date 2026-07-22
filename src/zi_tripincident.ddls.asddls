@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Child entity for Trip Transaction'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_TripIncident
  as select from ztab_tripitem
  association to parent ZI_TripHeader as _TripHeader on $projection.TripID = _TripHeader.TripID
  composition [0..*] of ZI_INC_ATT as _IAttachment
  association to I_CurrencyStdVH      as _Currency   on $projection.Currency = _Currency.Currency
  association to ZI_IncCategVH        as _Categories on $projection.IncidentCategory = _Categories.Category
{
  key i_id                    as IncidentID,
  key i_tripid                as TripID,
      i_cdate                 as IncidentDate,
      i_categ                 as IncidentCategory,
      i_descr                 as IncidentDescription,
      i_locn                  as IncidentLocation,
      @Semantics.amount.currencyCode: 'Currency'
      i_amount                as IncidentAmount,
      i_curr                  as Currency,
      i_rec_status            as ReceiptStatus,

      @Semantics.user.createdBy: true
      created_by              as IncidentCreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at              as CreateAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by         as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at         as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at   as LocalLastChangedAt,

      _Categories.Description as CategoryDescription,

      _TripHeader,
      _IAttachment,
      _Currency,
      _Categories
}
