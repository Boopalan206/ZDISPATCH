@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View - Attachment'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_INC_ATT1
  as projection on ZI_INC_ATT
{
  key IId,
  key TripID,
  key FildId,
      @Semantics.largeObject: {
            mimeType : 'FileMimetype',
            fileName : 'FileName',
            contentDispositionPreference: #ATTACHMENT
          }
      IncidentAttachment,
      @Semantics.mimeType: true
      FileMimetype,
      FileName,
      FileCreatedBy,
      CreateAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _TripHeader,
      _TripIncident : redirected to parent ZC_TripIncident
}
