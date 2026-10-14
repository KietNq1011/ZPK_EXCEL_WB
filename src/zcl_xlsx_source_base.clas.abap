"
" Gom phần lặp lại của mọi source class (ZIF_XLSX_SOURCE): đọc keys JSON,
" lấy ảnh asset (logo), render bắt buộc template hoặc có template dự phòng.
" Class con chỉ viết phần dữ liệu:
"
" - form_name( )                 — tên form trong ZXLSX_TMPL
" - zif_xlsx_source~get_context — đọc keys, dựng context (REF TO structure)
" - tuỳ chọn: zif_xlsx_source~get_sample (Preview), fallback_template( ),
"     file_name( )
"
"
" CLASS zcl_xlsx_my_form DEFINITION PUBLIC FINAL CREATE PUBLIC
"   INHERITING FROM zcl_xlsx_source_base.
"   PUBLIC SECTION.
"     METHODS form_name REDEFINITION.
"     METHODS zif_xlsx_source~get_context REDEFINITION.
" ENDCLASS.
"
" " gọi: NEW zcl_xlsx_my_form( )->render( `{ "vbeln": "90001234" }` )
"
CLASS zcl_xlsx_source_base DEFINITION
  PUBLIC ABSTRACT CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_xlsx_source ABSTRACT METHODS get_context.

    " Tên form = ZXLSX_TMPL-FORM_NAME (viết hoa)
    METHODS form_name ABSTRACT
      RETURNING VALUE(rv_form_name) TYPE string.

    " Dựng context từ keys rồi render. Template trong ZXLSX_TMPL luôn được ưu
    " tiên; chỉ khi class con có fallback_template( ) mới render được lúc bảng
    " chưa có form.
    " @parameter iv_keys | JSON, vd { "travel_id": "1" }
    METHODS render
      IMPORTING iv_keys        TYPE string OPTIONAL
      RETURNING VALUE(rs_file) TYPE zcl_xlsx_runtime=>ty_file
      RAISING   zcx_xlsx.

  PROTECTED SECTION.
    " Template dựng trong code (xstring). Rỗng = BẮT BUỘC có template trong bảng.
    METHODS fallback_template
      RETURNING VALUE(rv_template) TYPE xstring.

    " Engine của fallback_template( ): SSML (mặc định), XLSX hoặc DOCX
    METHODS fallback_engine
      RETURNING VALUE(rv_engine) TYPE string.

    " Tên file trả về; mặc định giữ tên runtime đặt
    METHODS file_name
      IMPORTING iv_keys        TYPE string
                is_file        TYPE zcl_xlsx_runtime=>ty_file
      RETURNING VALUE(rv_name) TYPE string.

    " Giá trị một key trong JSON (không phân biệt hoa thường)
    " @parameter iv_name | vd 'travel_id'
    METHODS key_value
      IMPORTING iv_keys         TYPE string
                iv_name         TYPE string
      RETURNING VALUE(rv_value) TYPE string
      RAISING   zcx_xlsx.

    " Ảnh asset (ENGINE = ASST) dạng base64; chưa upload thì trả rỗng
    METHODS asset_b64
      IMPORTING iv_asset      TYPE string
      RETURNING VALUE(rv_b64) TYPE string.
ENDCLASS.



CLASS zcl_xlsx_source_base IMPLEMENTATION.


  METHOD render.
    DATA(lr_context)  = zif_xlsx_source~get_context( iv_keys ).
    DATA(lv_fallback) = fallback_template( ).

    IF lv_fallback IS INITIAL.
      rs_file = zcl_xlsx_runtime=>render( iv_form_name = form_name( )
                                          ir_context   = lr_context ).
    ELSE.
      rs_file = zcl_xlsx_runtime=>render_prefer_table( iv_form_name         = form_name( )
                                                       iv_fallback_template = lv_fallback
                                                       iv_fallback_engine   = fallback_engine( )
                                                       ir_context           = lr_context ).
    ENDIF.

    rs_file-file_name = file_name( iv_keys = iv_keys is_file = rs_file ).
  ENDMETHOD.


  METHOD fallback_template.
    CLEAR rv_template.
  ENDMETHOD.


  METHOD fallback_engine.
    rv_engine = zcl_xlsx_runtime=>c_engine_ssml.
  ENDMETHOD.


  METHOD file_name.
    rv_name = is_file-file_name.
  ENDMETHOD.


  METHOD key_value.
    DATA(lr_keys) = zcl_xlsx_ctx_json=>parse( iv_keys ).
    IF lr_keys IS NOT BOUND.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |Keys rỗng — cần dạng \{ "{ iv_name }": "..." \}| ) ##NO_TEXT.
    ENDIF.

    ASSIGN lr_keys->* TO FIELD-SYMBOL(<ls_keys>).
    ASSIGN COMPONENT to_upper( iv_name ) OF STRUCTURE <ls_keys> TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |Keys thiếu "{ iv_name }" — cần dạng \{ "{ iv_name }": "..." \}| ) ##NO_TEXT.
    ENDIF.

    rv_value = condense( CONV string( <lv_value> ) ).
  ENDMETHOD.


  METHOD asset_b64.
    TRY.
        rv_b64 = zcl_xlsx_runtime=>get_asset_b64( iv_asset ).
      CATCH zcx_xlsx.
        CLEAR rv_b64.        " chưa upload asset -> form in không có ảnh
    ENDTRY.
  ENDMETHOD.


  METHOD zif_xlsx_source~get_sample.
    " mặc định không có dữ liệu mẫu — class con redefine nếu cần Preview
    CLEAR rr_context.
  ENDMETHOD.
ENDCLASS.
