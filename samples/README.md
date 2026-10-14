# Template mẫu

Upload qua app `ZUI_XLSX_TMPL_O4` (Create → Template file + Sample JSON → Save → Preview).
Thư mục này nằm ngoài `/src/` nên abapGit không pull lên SAP.

| Form | Engine | Template | Sample JSON | Ghi chú |
|---|---|---|---|---|
| `ORDER_FORM` | `SSML` | `ORDER_FORM_template.xml` | `ORDER_FORM_sample.json` | Đơn đặt hàng, XML Spreadsheet 2003, không có logo |
| `ORDER_FORM_X` | `XLSX` | `ORDER_FORM_X_template.xlsx` | `ORDER_FORM_X_sample.json` | Như trên + logo `{{*image:logo@2x4}}` ở A1:B4 |

Kết quả Preview của `ORDER_FORM` / `ORDER_FORM_X`: 3 dòng hàng, cộng tiền hàng 40.275.000, thuế GTGT 8% 3.222.000,
tổng thanh toán 43.497.000.

## Logo

- `LOGO_DEMO.png`: logo mẫu 200×110 (tỉ lệ ~1,8:1 khớp vùng A1:B4). Upload làm template
  Engine `ASST` (ví dụ `LOGO_COMPANY`) rồi lấy bằng `zcl_xlsx_runtime=>get_asset_b64( 'LOGO_COMPANY' )`.
- Chỉ nhận PNG. Logo bị kéo giãn theo vùng ô neo, nên chỉnh độ rộng cột A/B hoặc chiều cao
  dòng 1–4 cho khớp tỉ lệ logo thật.
- Trong `@CxR` hiện chỉ số cột (C) có tác dụng, số dòng luôn là 4.
- Không dán thêm ảnh tĩnh vào sheet có `{{*image}}`: engine ghi `drawing1.xml` riêng.

## Sinh lại bản .xlsx

`build_order_xlsx.py` dựng `ORDER_FORM_X_template.xlsx`, `LOGO_DEMO.png` và
`ORDER_FORM_X_sample.json` (đọc `ORDER_FORM_sample.json` trong cùng thư mục). Cần `openpyxl`.
Template của app mẫu (DMO_TRAVEL, ZDMO01) nằm ở repo app.

```
py -X utf8 build_order_xlsx.py .
```
