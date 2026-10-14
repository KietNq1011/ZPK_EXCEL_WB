@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'XLSX Excel template'
@ObjectModel.semanticKey: [ 'FormName' ]
define root view entity ZC_XLSX_TMPL
  provider contract transactional_query
  as projection on ZR_XLSX_TMPL
{
      // bảng dùng kiểu built-in (không data element) -> phải tự khai label,
      // thiếu label thì dialog Create của Fiori chỉ hiện dấu * trống
      @EndUserText.label: 'Form name'
  key FormName,
      @EndUserText.label: 'Description'
      Descr,
      @EndUserText.label: 'Engine (SSML/XLSX/DOCX/ASST)'
      @EndUserText.quickInfo: 'SSML=XML 2003, XLSX=.xlsx, DOCX=Word, ASST=PNG image'
      Engine,

      @EndUserText.label: 'MIME type'
      @Semantics.mimeType: true
      MimeType,
      @EndUserText.label: 'File name'
      FileName,
      @EndUserText.label: 'Active'
      IsActive,

      @Semantics.largeObject: { mimeType: 'MimeType',
                                fileName: 'FileName',
                                acceptableMimeTypes: [ 'application/vnd.ms-excel',
                                                       'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                                                       'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'image/png', 'text/xml' ],
                                contentDispositionPreference: #ATTACHMENT }
      @EndUserText.label: 'Template file'
      Template,

      @EndUserText.label: 'Source class'
      SourceClass,
      @EndUserText.label: 'Sample JSON'
      SampleJson,

      @EndUserText.label: 'Preview MIME type'
      @Semantics.mimeType: true
      PreviewMime,
      @EndUserText.label: 'Preview file name'
      PreviewName,
      @EndUserText.label: 'Preview file'
      @Semantics.largeObject: { mimeType: 'PreviewMime',
                                fileName: 'PreviewName',
                                contentDispositionPreference: #ATTACHMENT }
      PreviewFile,

      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt
}
