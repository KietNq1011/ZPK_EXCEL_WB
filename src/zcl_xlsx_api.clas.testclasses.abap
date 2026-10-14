CLASS ltcl_api DEFINITION DEFERRED.
CLASS zcl_xlsx_api DEFINITION LOCAL FRIENDS ltcl_api.

"! Không đụng DB: asset (get_asset_b64) không test ở đây, chỉ test phần chèn JSON
"! và render với template truyền thẳng.
CLASS ltcl_api DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS add_value_to_object FOR TESTING RAISING zcx_xlsx.
    METHODS add_value_to_empty  FOR TESTING RAISING zcx_xlsx.
    METHODS reject_non_object   FOR TESTING.
    METHODS reject_bad_key      FOR TESTING.
    METHODS render_ssml_json    FOR TESTING RAISING zcx_xlsx.

    METHODS out_text
      IMPORTING iv_content     TYPE xstring
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


CLASS ltcl_api IMPLEMENTATION.

  METHOD add_value_to_object.
    DATA(lv_json) = zcl_xlsx_api=>add_root_value( iv_json  = ` { "a": 1 }`
                                                  iv_key   = `logo`
                                                  iv_value = `QUJD` ).
    cl_abap_unit_assert=>assert_equals( act = lv_json exp = ` {"logo":"QUJD", "a": 1 }` ).
    cl_abap_unit_assert=>assert_bound( zcl_xlsx_ctx_json=>parse( lv_json ) ).
  ENDMETHOD.


  METHOD add_value_to_empty.
    DATA(lv_json) = zcl_xlsx_api=>add_root_value( iv_json  = `{}`
                                                  iv_key   = `logo`
                                                  iv_value = `QUJD` ).
    cl_abap_unit_assert=>assert_equals( act = lv_json exp = `{"logo":"QUJD"}` ).
    cl_abap_unit_assert=>assert_bound( zcl_xlsx_ctx_json=>parse( lv_json ) ).
  ENDMETHOD.


  METHOD reject_non_object.
    TRY.
        zcl_xlsx_api=>add_root_value( iv_json = `[ 1, 2 ]` iv_key = `logo` iv_value = `QUJD` ).
        cl_abap_unit_assert=>fail( msg = `JSON gốc là array phải bị từ chối` ).
      CATCH zcx_xlsx ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD reject_bad_key.
    TRY.
        zcl_xlsx_api=>add_root_value( iv_json = `{}` iv_key = `lo"go` iv_value = `QUJD` ).
        cl_abap_unit_assert=>fail( msg = `Key có ký tự lạ phải bị từ chối` ).
      CATCH zcx_xlsx ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD render_ssml_json.
    DATA(lv_template) =
      `<?xml version="1.0"?>` &&
      `<?mso-application progid="Excel.Sheet"?>` &&
      `<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"` &&
      ` xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"` &&
      ` xmlns:x="urn:schemas-microsoft-com:office:excel">` &&
      `<Worksheet ss:Name="T"><Table>` &&
      `<Row><Cell><Data ss:Type="String">Hello {{customer.name}}</Data></Cell></Row>` &&
      `<Row><Cell><Data ss:Type="String">{{#items}}{{matnr}}{{/items}}</Data></Cell></Row>` &&
      `</Table></Worksheet></Workbook>`.

    DATA(ls_res) = zcl_xlsx_api=>render_json_with_template(
      iv_template  = cl_abap_conv_codepage=>create_out( )->convert( lv_template )
      iv_engine    = `SSML`
      iv_json      = `{ "customer": { "name": "ACME" },` &&
                     `  "items": [ { "matnr": "MAT-001" }, { "matnr": "MAT-002" } ] }`
      iv_file_name = `test.xlsx` ).

    cl_abap_unit_assert=>assert_not_initial( act = ls_res-content     msg = `content` ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_res-content_b64 msg = `content_b64` ).
    cl_abap_unit_assert=>assert_equals( act = ls_res-file_name exp = `test.xlsx` ).

    DATA(lv_text) = out_text( ls_res-content ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_text CS `Hello ACME` ) msg = `giá trị lồng nhau` ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_text CS `MAT-002` )    msg = `dòng lặp thứ 2` ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( lv_text CS `{{` )        msg = `còn placeholder` ).
  ENDMETHOD.


  METHOD out_text.
    " .xlsx là zip -> nối text mọi part; .xls (SSML gốc) là text
    DATA lv_magic TYPE x LENGTH 2.
    IF xstrlen( iv_content ) >= 2.
      lv_magic = iv_content.
    ENDIF.
    IF lv_magic <> CONV xstring( '504B' ).
      rv_text = cl_abap_conv_codepage=>create_in( )->convert( iv_content ).
      RETURN.
    ENDIF.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( iv_content ).
    LOOP AT lo_zip->files INTO DATA(ls_f).
      lo_zip->get( EXPORTING name = ls_f-name
                   IMPORTING content = DATA(lv_raw)
                   EXCEPTIONS zip_index_error = 1 OTHERS = 2 ).
      IF sy-subrc = 0 AND lv_raw IS NOT INITIAL.
        rv_text &&= cl_abap_conv_codepage=>create_in( )->convert( lv_raw ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
