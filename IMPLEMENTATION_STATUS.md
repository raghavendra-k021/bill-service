# Implementation Status

**Project directory:** `bill-service` (working copy) · **Package:** `com.billingservice.app`

## ✅ Completed Features

### 1. Project Setup ✅
- Flutter project in `bill-service/`
- Dependencies in `pubspec.yaml`
- Android manifest, Gradle, permissions (camera, Bluetooth, storage)
- Documentation set (README, ARCHITECTURE, PRINTING_GUIDE, testing, setup, build guides)

### 2. Database Layer ✅
- Tables: users, products, customers, invoices, invoice_items, stock_history, categories, shop_settings
- DAOs for all entities; default admin user on first run
- Shop settings: logo path, **footer**, **shop_code**, optional phone

**Schema version:** 5

**Run before first build:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Services Layer ✅
| Service | Capabilities |
|---------|----------------|
| **AuthService** | Login, password hash, biometric |
| **GSTCalculator** | Per-product GST %; GST after discount; **PriceUtils rounding** |
| **BillingService** | Invoice creation, stock deduction, rounded totals |
| **InventoryService** | CRUD, search, **getProductByBarcode**, **createProductFromBilling** |
| **ReportService** | Sales/GST reports, invoice PDF, Excel export |
| **PrintService** | Dual BT slots, receipt 80 mm, **2×1.5 in CODE128 labels**, **invoice QR footer** |
| **BackupService** | Encrypted Google Drive backup |

### 4. Billing (POS) ✅
- Product search (**starts with**), browse all, camera **CODE128** scan
- **Scan label barcode** → `getProductByBarcode` → add to cart
- **Add to cart dialog:** quantity, **editable price**, **discount %**
- **Edit cart:** tap price line in cart
- **New item flow:** not in inventory → dialog → **saved to inventory + cart**
- Customer, payment mode, bill summary, save & optional auto-print
- **Whole-rupee rounding** on all line totals and bill total

### 5. Inventory & Labels ✅
- Product form (barcode, prices, GST %, default discount %, stock, units)
- **BarcodeScreen:** label preview (2"×1.5"), Share PDF, Print with **copy count (1–999)**
- **Thermal labels:** CODE128 bitmap — MRP, -10%, SRT PRICE, tax line, barcode, product name
- **LabelQrCodec:** shop code resolve + `netPriceFrom` (signed QR build/parse retained but not used for labels/billing)
- Low stock alerts (min stock default **0**)

### 6. Bills & Printing ✅
- Bills list (amount **excl. GST**), date filter, detail view
- Invoice PDF: dynamic page height, logo header, item lines, TOTAL DISCOUNT, Gross Total, GST, payment
- **Footer:** custom text **left-aligned**; **QR code right** (`INV:…|SC:…|AMT:…|DT:…`)
- Invoice QR uses **imageRaster** (GS v 0) for reliable phone scanning
- Thermal receipt matches PDF layout (shared header bitmap, formatting)
- Bill detail: PDF share, print button

### 7. Reports ✅
- **Sales report cards:** Total Sales (excl. GST), Total GST, Total (incl. GST), invoice count, average (excl. GST)
- **Excel:** Subtotal (excl. GST), GST, Total columns
- GST report, analytics chart
- Dashboard today's sales uses total **incl. GST** (cash collected)

### 8. Settings ✅
- Shop summary + **Edit Shop Details** screen (logo picker, address, **shop code**, **phone optional**, email, GSTIN, state, footer)
- **Dual Bluetooth printers:** receipt 80 mm + label **2"×1.5"** — separate scan/connect/test/disconnect
- Google Drive backup, user management (admin)

### 9. Receipt / Label Formatting ✅
- Shop name wrap; logo aspect ratio; INVOICE + DATE on one line
- Item table: bold headers, short units (`m`, `p`), separators
- **TOTAL DISCOUNT** (bold, centered)
- Gross Total (large); Total Items line; CGST/SGST/Total GST breakdown
- Full-width horizontal rules
- **Label:** trim top whitespace, 252-dot pitch, gap-sensor multi-copy (`GS V 1`)
- **Prices:** round to whole rupees, display with `.00`

## 📋 Feature Checklist (Current)

- [x] Dual printers (receipt 80 mm + label Posiflow P58D 2"×1.5")
- [x] CODE128 product labels (not signed QR on label)
- [x] Billing scan reads label CODE128 barcode
- [x] Shop code on label price line + invoice QR (`SC:` field)
- [x] Label print copy count (1–999) with gap-sensor alignment
- [x] MRP left / -10% right / SRT PRICE bold same size
- [x] Whole-rupee rounding everywhere with `.00` display
- [x] Invoice QR scannable (imageRaster + quiet zone)
- [x] Sales report GST split (excl / GST / incl)
- [x] Editable price/discount when adding to cart
- [x] Add unknown product to inventory from billing
- [x] Shop details edit screen + collapsed settings card

## ⚠️ Important Notes

### Default Login
- **Username:** `admin` · **Password:** `admin123`

### Permissions
- Camera (barcode scan)
- Bluetooth (printer — optional)
- Internet (backup — optional)

### Printer Notes
- **Receipt printer (80 mm):** bills only — prefer **SPP** (e.g. CN811)
- **Label printer (Posiflow P58D):** **2" × 1.5"** gap labels only
- Both can stay connected; prefs: `receipt_printer_*` and `label_printer_*`
- **Reprint labels** after changing shop code so price line prefix matches
- See [PRINTING_GUIDE.md](PRINTING_GUIDE.md) for gap sensor and troubleshooting

## 🔄 Optional Future Enhancements

1. Category management UI
2. Bulk product import (Excel/CSV)
3. Full user management UI
4. Scan invoice QR to open bill detail in app
5. Multi-device sync

## 📱 Testing Checklist

- [ ] Login, add products, print label — **scan barcode at billing** adds item
- [ ] Dual printers: receipt test on CN811, label test on P58D
- [ ] Print 2+ labels — each copy identical full layout
- [ ] Save bill — receipt QR scans with `INV|SC|AMT|DT`
- [ ] Amounts round to whole rupees with `.00`
- [ ] Change shop code → reprint label → invoice QR shows new `SC:`

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed test cases.
