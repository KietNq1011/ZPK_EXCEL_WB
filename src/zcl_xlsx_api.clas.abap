"! <p class="shorttext synchronized" lang="en">XLSX: shared API - JSON in, file out</p>
"!
"! Điểm gọi dùng chung cho chương trình khác: truyền tên form (template trong
"! ZXLSX_TMPL) + dữ liệu dạng chuỗi JSON, nhận lại file đã render.
"! <pre>
"! DATA(ls_file) = zcl_xlsx_api=>render_json(
"!   iv_form_name = 'ORDER_FORM_X'
"!   iv_json      = lv_json
"!   it_assets    = VALUE #( ( key = 'logo' asset = 'LOGO_COMPANY' ) ) ).
"! " ls_file-content (xstring) / content_b64 / mime_type / file_name
"! </pre>
"! Quy tắc JSON → context (ZCL_XLSX_CTX_JSON): object → structure, array → bảng
"! (cấu trúc theo phần tử đầu), number → decfloat34, "YYYY-MM-DD" → ngày,
"! true/false → abap_bool. Key thành tên field: chữ hoa, ký tự ngoài A-Z 0-9 _
"! đổi thành _, tối đa 30 ký tự — placeholder trong template viết theo key.
CLASS zcl_xlsx_api DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_asset,
             key   TYPE string,   " key chèn vào gốc JSON, vd logo -> {{*image:logo}}
             asset TYPE string,   " FORM_NAME của dòng ENGINE = ASST trong ZXLSX_TMPL
           END OF ty_asset,
           tt_assets TYPE STANDARD TABLE OF ty_asset WITH EMPTY KEY.

    TYPES: BEGIN OF ty_result,
             content     TYPE xstring,
             content_b64 TYPE string,
             mime_type   TYPE string,
             file_name   TYPE string,
             extension   TYPE string,
           END OF ty_result.

    "! Render template trong ZXLSX_TMPL với dữ liệu JSON
    "! @parameter iv_form_name | FORM_NAME trong ZXLSX_TMPL (template phải Active)
    "! @parameter iv_json      | dữ liệu, gốc là object { ... }
    "! @parameter it_assets    | ảnh (ENGINE = ASST) chèn vào gốc JSON dưới tên key
    "! @parameter iv_file_name | tên file trả về; trống = theo template
    CLASS-METHODS render_json
      IMPORTING iv_form_name     TYPE string
                iv_json          TYPE string
                it_assets        TYPE tt_assets OPTIONAL
                iv_file_name     TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_xlsx.

    "! Như render_json nhưng template truyền thẳng (không đọc ZXLSX_TMPL)
    "! @parameter iv_engine | SSML, XLSX hoặc DOCX
    CLASS-METHODS render_json_with_template
      IMPORTING iv_template      TYPE xstring
                iv_engine        TYPE string
                iv_json          TYPE string
                it_assets        TYPE tt_assets OPTIONAL
                iv_file_name     TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_xlsx.

  PRIVATE SECTION.
    "! Lấy base64 của từng asset rồi chèn vào gốc JSON
    CLASS-METHODS inject_assets
      IMPORTING iv_json        TYPE string
                it_assets      TYPE tt_assets
      RETURNING VALUE(rv_json) TYPE string
      RAISING   zcx_xlsx.

    "! Thêm cặp "key":"value" ngay sau dấu { gốc của JSON.
    "! value không được escape — chỉ dùng cho chuỗi an toàn như base64
    CLASS-METHODS add_root_value
      IMPORTING iv_json        TYPE string
                iv_key         TYPE string
                iv_value       TYPE string
      RETURNING VALUE(rv_json) TYPE string
      RAISING   zcx_xlsx.

    CLASS-METHODS to_result
      IMPORTING is_file          TYPE zcl_xlsx_runtime=>ty_file
                iv_file_name     TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.
ENDCLASS.



CLASS zcl_xlsx_api IMPLEMENTATION.


  METHOD render_json.
    DATA(lr_ctx) = zcl_xlsx_ctx_json=>parse( inject_assets( iv_json   = iv_json
                                                            it_assets = it_assets ) ).
    rs_result = to_result( is_file      = zcl_xlsx_runtime=>render( iv_form_name = iv_form_name
                                                                    ir_context   = lr_ctx )
                           iv_file_name = iv_file_name ).
  ENDMETHOD.


  METHOD render_json_with_template.
    DATA(lr_ctx) = zcl_xlsx_ctx_json=>parse( inject_assets( iv_json   = iv_json
                                                            it_assets = it_assets ) ).
    rs_result = to_result( is_file      = zcl_xlsx_runtime=>render_with_template(
                                            iv_template = iv_template
                                            iv_engine   = iv_engine
                                            ir_context  = lr_ctx )
                           iv_file_name = iv_file_name ).
  ENDMETHOD.


  METHOD inject_assets.
    rv_json = iv_json.
    LOOP AT it_assets INTO DATA(ls_asset).
      rv_json = add_root_value( iv_json  = rv_json
                                iv_key   = ls_asset-key
                                iv_value = zcl_xlsx_runtime=>get_asset_b64( ls_asset-asset ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD add_root_value.
    IF iv_key IS INITIAL
    OR iv_key CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |Key '{ iv_key }' không hợp lệ (chỉ A-Z, 0-9, _)| ).
    ENDIF.

    " gốc phải là object; nhóm 1 bắt "}" khi object rỗng để không thêm dấu phẩy
    DATA lv_close TYPE string.
    FIND FIRST OCCURRENCE OF PCRE '(?-x)^\s*\{\s*(\}?)' IN iv_json SUBMATCHES lv_close.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_xlsx( iv_text = |JSON gốc phải là object \{ ... \} để chèn '{ iv_key }'| ).
    ENDIF.

    DATA(lv_pos) = find( val = iv_json sub = `{` ) + 1.
    rv_json = substring( val = iv_json len = lv_pos )
           && |"{ iv_key }":"{ iv_value }"|
           && COND string( WHEN lv_close IS INITIAL THEN `,` )
           && substring( val = iv_json off = lv_pos ).
  ENDMETHOD.


  METHOD to_result.
    rs_result = VALUE #( content     = is_file-content
                         content_b64 = cl_web_http_utility=>encode_x_base64( is_file-content )
                         mime_type   = is_file-mime_type
                         file_name   = COND #( WHEN iv_file_name IS NOT INITIAL THEN iv_file_name
                                               ELSE is_file-file_name )
                         extension   = is_file-extension ).
  ENDMETHOD.
ENDCLASS.
