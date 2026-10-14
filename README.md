# ZPK_EXCEL_WB

Excel Workbench cho ABAP Cloud (BTP ABAP Environment / S/4HANA Cloud Public): render file Excel (.xlsx) và
Word (.docx) từ template có placeholder `{{...}}`, và lưu file vào bộ attachment cho app RAP in/xuất file.

Gom framework từ hai repo trước đây:
- [ZPK_XLSX](https://github.com/KietNq1011/ZPK_XLSX) (commit `9d3eb9e`): engine, runtime, app quản lý template.
- [ZPK_XLSX_ATT](https://github.com/KietNq1011/ZPK_XLSX_ATT) (commit `8de31de`): `ZCL_XLSX_SOURCE_BASE`, `ZCL_XLSX_ATT_EXPORT`.

Tên object giữ nguyên (`ZCL_XLSX_*`, `ZXLSX_TMPL`…), chỉ đổi package. Đã bỏ `ZCL_XLSX_API` (không nơi nào gọi).
App mẫu (Travel, ZDMO01) không nằm ở đây.

## Package

Một package `ZPK_EXCEL_WB`, không có subpackage: engine + runtime + app template + `ZCL_XLSX_SOURCE_BASE` + `ZCL_XLSX_ATT_EXPORT`.

Phụ thuộc một chiều: [`ZPK_ATTACHMENT`](https://github.com/KietNq1011/ZPK_ATTACHMENT) → `ZPK_EXCEL_WB` → app.
Chỉ `ZCL_XLSX_ATT_EXPORT` dùng attachment, nhưng vì cùng package nên phải cài `ZPK_ATTACHMENT` trước.

## Object

| Mức | Object | Vai trò |
|---|---|---|
| Engine | `ZCX_XLSX` | Exception chung |
| | `ZCL_XLSX_CTX` | Phân giải placeholder, vòng lặp, aggregate (dùng chung các engine) |
| | `ZCL_XLSX_ENGINE` | Engine SpreadsheetML (template XML Spreadsheet 2003) |
| | `ZCL_XLSX_SSML2XLSX` | Chuyển SpreadsheetML → .xlsx |
| | `ZCL_XLSX_XLSX` | Engine XLSX (template .xlsx thật: logo, chart, conditional formatting) |
| | `ZCL_XLSX_DOCX` | Engine DOCX |
| Runtime | `ZXLSX_TMPL` | Bảng template (FORM_NAME, ENGINE, TEMPLATE, SOURCE_CLASS, SAMPLE_JSON…) |
| | `ZCL_XLSX_RUNTIME` | API: `render`, `render_with_template`, `render_prefer_table`, `render_by_source`, `get_asset_b64` |
| | `ZIF_XLSX_SOURCE` | Interface cho source class lấy dữ liệu thật |
| | `ZCL_XLSX_SOURCE_BASE` | Class cha cho source class: `render`, `key_value`, `asset_b64`, template dự phòng |
| App template | `ZXLSX_TMPL_D`, `ZR_XLSX_TMPL`, `ZC_XLSX_TMPL`, `ZBP_R_XLSX_TMPL`, `ZXLSX_A_JSON_P` | RAP BO (draft) quản lý template |
| | `ZCL_XLSX_CTX_JSON`, `ZCL_XLSX_TMPL_UTIL` | JSON → context; validate / export / import template |
| | `ZUI_XLSX_TMPL`, `ZUI_XLSX_TMPL_O4` | Service definition / binding OData V4 UI |
| Attachment | `ZCL_XLSX_ATT_EXPORT` | `export`: render + thay file của document trong `ZR_ATTACHMENT_DMO`; `save`: lưu file có sẵn |

## Cài đặt

1. Pull + activate [`ZPK_ATTACHMENT`](https://github.com/KietNq1011/ZPK_ATTACHMENT).
2. ADT → abapGit Repositories → Link: URL repo này, branch `main`, package `ZPK_EXCEL_WB` → Pull.
3. Activate các object còn inactive (Ctrl+Shift+F3). Lỗi thứ tự activate thì activate `ZCX_XLSX` trước.
4. `ZUI_XLSX_TMPL_O4` → Publish → Preview để dùng app quản lý template.
5. Người dùng thật: tạo IAM App cho `ZUI_XLSX_TMPL_O4`, gán Business Catalog / Business Role
   (IAM object sinh theo từng hệ thống, repo không mang theo).

### Hệ thống đã cài ZPK_XLSX / ZPK_XLSX_ATT (vd BTP TRIAL)

Object cùng tên đang nằm ở package cũ ⇒ abapGit báo object thuộc package khác. Trước khi pull:

1. Tạo package `ZPK_EXCEL_WB`.
2. ADT → chọn object → *Change Package Assignment*:
   - mọi object trong `ZPK_XLSX` (trừ subpackage `ZPK_XLSX_DEMO` và `ZCL_XLSX_API`) → `ZPK_EXCEL_WB`
   - `ZCL_XLSX_SOURCE_BASE`, `ZCL_XLSX_ATT_EXPORT` (đang ở `ZPK_XLSX_ATT`) → `ZPK_EXCEL_WB`
   - `ZCL_XLSX_API`: xoá (repo không còn class này)
3. Link repo này vào `ZPK_EXCEL_WB` → Pull. Dữ liệu bảng `ZXLSX_TMPL` (template đã upload) giữ nguyên vì tên bảng không đổi.

## Dùng

```abap
" render theo template trong ZXLSX_TMPL (upload qua app), engine chọn theo cột ENGINE
DATA(ls_file) = zcl_xlsx_runtime=>render( iv_form_name = 'ORDER_FORM'
                                          ir_context   = REF #( ls_ctx ) ).
" ls_file-content (xstring) / ls_file-mime_type / ls_file-file_name

" action RAP: render + lưu vào bộ attachment (khuôn ZWM13A)
DATA(lo_export) = NEW zcl_xlsx_att_export( iv_module = 'MM' iv_app_id = 'ZMM_PO_PRINT' ).
lo_export->export( iv_form_name   = 'PO_FORM'
                   iv_document_id = CONV #( ls_key-PurchaseOrder )
                   iv_keys        = |\{ "po": "{ ls_key-PurchaseOrder }" \}|
                   iv_file_stem   = |PO_{ ls_key-PurchaseOrder }| ).
```

Source class mới: kế thừa `ZCL_XLSX_SOURCE_BASE`, redefine `form_name( )` + `zif_xlsx_source~get_context`.
App mẫu đầy đủ (CDS 3 tầng, BDEF, DDLX, service): [ZDMO01](https://github.com/KietNq1011/ZDMO01).

Placeholder chính:

| Cú pháp | Ý nghĩa |
|---|---|
| `{{field}}`, `{{a.b}}` | Giá trị đơn / path lồng nhau (phân cách bằng dấu chấm) |
| `{{@index}}`, `{{@count}}` | Số thứ tự dòng (từ 1) / tổng số dòng của vòng lặp gần nhất |
| `{{?path}}…{{/path}}`, `{{^path}}…{{/path}}` | Khối điều kiện: giữ khi có giá trị / khi rỗng |
| `{{sum:items.amount}}`, `{{cnt:items}}` | Aggregate (`sum`, `avg`, `min`, `max`, `cnt`) |
| `{{#items}}…{{/items}}` | Lặp dòng |
| `{{#cols>}}` | Lặp ô ngang (cột động) |
| `{{*mergedown:path}}`, `{{*mergesame:path}}` | Gộp ô |
| `{{*break}}` | Ngắt trang |
| `{{*image:path}}`, `{{*image:path@CxR}}` | Chèn ảnh base64 PNG (chỉ engine XLSX), mặc định 2 cột x 4 dòng. Hiện chỉ C (số cột) có tác dụng, số dòng luôn là 4 |

Template mẫu (đơn đặt hàng SSML và XLSX có logo) nằm trong [samples/](samples/).

## Lưu ý

- Form Name trong app template được lưu đúng như gõ, còn runtime tìm bằng chữ hoa ⇒ đặt Form Name **viết hoa**.
- `ZCL_XLSX_ATT_EXPORT` gọi thẳng `ZR_ATTACHMENT_DMO` (bản copy cho TRIAL). Hệ thống có `ZATTACHMENT` gốc
  (`ZR_ATTACHMENT`) cần bản riêng của class này.
