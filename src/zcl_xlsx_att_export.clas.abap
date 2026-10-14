"
" Logic action "in / xuất file" theo khuôn ZWM13A, dùng chung cho mọi app:
" render template (ZCL_XLSX_RUNTIME) rồi thay file của document trong bộ
" attachment ZR_ATTACHMENT_DMO (tạo bản mới, xoá bản cũ). App đọc lại file
" bằng ZI_ATTACHMENT_DMO( p_module_obj, p_app_id ) join theo DocumentId.
" Chỉ gọi trong behavior handler (interaction phase): framework lưu cùng
" LUW với BO gọi — KHÔNG COMMIT ENTITIES.
"
" DATA(lo_export) = NEW zcl_xlsx_att_export( iv_module = 'DMO' iv_app_id = 'ZXLSX_DEMO' ).
" LOOP AT keys INTO DATA(ls_key).
"   TRY.
"       " dữ liệu qua source class gán trên template (cột SOURCE_CLASS)
"       lo_export->export( iv_form_name   = 'DMO_TRAVEL'
"                          iv_document_id = CONV #( ls_key-TravelID )
"                          iv_keys        = |\{ "travel_id": "{ ls_key-TravelID }" \}| ).
"     CATCH zcx_xlsx INTO DATA(lx).
"       " failed + reported cho key này
"   ENDTRY.
" ENDLOOP.
"
CLASS zcl_xlsx_att_export DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " @parameter iv_module | nhóm file, vd 'WM', 'DMO'
    " @parameter iv_app_id | app sở hữu file, vd 'ZWM13A', 'ZXLSX_DEMO'
    METHODS constructor
      IMPORTING iv_module TYPE zde_module_object_dmo
                iv_app_id TYPE zde_app_id_dmo.

    " Render form rồi lưu thành file của document (thay file cũ).
    " Dữ liệu lấy từ ir_context (dựng sẵn) — nếu không truyền thì từ source
    " class của template với iv_keys.
    " @parameter iv_form_name   | ZXLSX_TMPL-FORM_NAME
    " @parameter iv_document_id | khoá nghiệp vụ, app join theo cột này
    " @parameter iv_keys        | JSON cho ZIF_XLSX_SOURCE~GET_CONTEXT
    " @parameter ir_context     | REF TO structure đã dựng
    " @parameter iv_file_stem   | tên file không đuôi; đuôi theo engine (xlsx/xls/docx)
    METHODS export
      IMPORTING iv_form_name   TYPE string
                iv_document_id TYPE zde_document_id_dmo
                iv_keys        TYPE string OPTIONAL
                ir_context     TYPE REF TO data OPTIONAL
                iv_file_stem   TYPE string OPTIONAL
      RETURNING VALUE(rs_file) TYPE zcl_xlsx_runtime=>ty_file
      RAISING   zcx_xlsx.

    " Lưu file đã có sẵn (vd PDF render bằng ADS) — thay file cũ của document
    METHODS save
      IMPORTING iv_document_id TYPE zde_document_id_dmo
                is_file        TYPE zcl_xlsx_runtime=>ty_file
      RAISING   zcx_xlsx.

  PRIVATE SECTION.
    DATA mv_module TYPE zde_module_object_dmo.
    DATA mv_app_id TYPE zde_app_id_dmo.

    " %cid duy nhất trong LUW khi lưu nhiều document
    CLASS-DATA gv_seq TYPE i.
ENDCLASS.



CLASS zcl_xlsx_att_export IMPLEMENTATION.


  METHOD constructor.
    mv_module = iv_module.
    mv_app_id = iv_app_id.
  ENDMETHOD.


  METHOD export.
    IF ir_context IS BOUND.
      rs_file = zcl_xlsx_runtime=>render( iv_form_name = iv_form_name
                                          ir_context   = ir_context ).
    ELSE.
      rs_file = zcl_xlsx_runtime=>render_by_source( iv_form_name = iv_form_name
                                                    iv_keys      = iv_keys ).
    ENDIF.

    IF iv_file_stem IS NOT INITIAL.
      rs_file-file_name = |{ iv_file_stem }.{ rs_file-extension }| ##NO_TEXT.
    ENDIF.

    save( iv_document_id = iv_document_id
          is_file        = rs_file ).
  ENDMETHOD.


  METHOD save.
    IF iv_document_id IS INITIAL.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |Document ID rỗng — không lưu được file| ) ##NO_TEXT.
    ENDIF.

    gv_seq += 1.
    DATA(lv_cid)      = |XATT{ gv_seq }| ##NO_TEXT.
    DATA(lv_cid_item) = |XATT{ gv_seq }I| ##NO_TEXT.

    " tạo bản mới trước — lỗi thì file cũ vẫn còn
    MODIFY ENTITIES OF zr_attachment_dmo
           ENTITY attachment
           CREATE FIELDS ( moduleobject appid attachment filename mimetype )
           WITH VALUE #( ( %cid         = lv_cid
                           moduleobject = mv_module
                           appid        = mv_app_id
                           attachment   = is_file-content
                           filename     = is_file-file_name
                           mimetype     = is_file-mime_type ) )
           ENTITY attachment
           CREATE BY \_attachmentitem
           FIELDS ( documentid )
           WITH VALUE #( ( %cid_ref = lv_cid
                           %target  = VALUE #( ( %cid       = lv_cid_item
                                                 documentid = iv_document_id ) ) ) )
           FAILED DATA(ls_failed).

    IF ls_failed IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |Không lưu được file cho document { iv_document_id }| ) ##NO_TEXT.
    ENDIF.

    " bản cũ: delete_attachment đọc DB nên không chạm bản vừa tạo (còn trong buffer)
    NEW zcl_attachment_dmo( )->delete_attachment( i_appid        = CONV string( mv_app_id )
                                                  i_moduleobject = CONV string( mv_module )
                                                  i_documentid   = iv_document_id ).
  ENDMETHOD.
ENDCLASS.
