"! <p class="shorttext synchronized" lang="en">XLSX: data source for a form</p>
"!
"! Mỗi form nghiệp vụ implement interface này một lần; app template gán
"! class vào cột SOURCE_CLASS của ZXLSX_TMPL. Runtime gọi
"! {@link zcl_xlsx_runtime.METH:render_by_source} để đổ dữ liệu thật.
INTERFACE zif_xlsx_source PUBLIC.

  "! Dữ liệu thật cho form.
  "! @parameter iv_keys | tham số chọn dạng JSON, vd { "vbeln": "90001234" }
  "! @parameter rr_context | REF TO structure/table đưa thẳng vào engine
  METHODS get_context
    IMPORTING iv_keys           TYPE string OPTIONAL
    RETURNING VALUE(rr_context) TYPE REF TO data
    RAISING   zcx_xlsx.

  "! Dữ liệu mẫu — dùng cho Preview khi SAMPLE_JSON của template chưa nhập
  METHODS get_sample
    RETURNING VALUE(rr_context) TYPE REF TO data.

ENDINTERFACE.
