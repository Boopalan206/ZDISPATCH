@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS view for Incident Attachment'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_INC_ATT
  as select from ztab_inc_att
  association to parent ZI_TripIncident as _TripIncident on  $projection.IId    = _TripIncident.IncidentID
                                                         and $projection.TripID = _TripIncident.TripID
  association to ZI_TripHeader          as _TripHeader   on  $projection.TripID = _TripHeader.TripID

{
  key i_id                  as IId,
  key i_tripid              as TripID,
  key f_id                  as FildId,
      inc_att               as IncidentAttachment,
      mimetype              as FileMimetype,
      filename              as FileName,

      @Semantics.user.createdBy: true
      created_by            as FileCreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreateAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _TripHeader,
      _TripIncident
}
