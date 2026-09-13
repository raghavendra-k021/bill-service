# Billing Service Android Application

A comprehensive Android mobile billing application for any type of business, built with Flutter. The **working copy** of this project is the **`bill-service`** directory (`com.billingservice.app`).

## Features

### Point of Sale (Billing)
- Camera-based **CODE128 scanning** — scan product label barcode to add to cart
- **Product search** by barcode or name **starts with** (e.g. `"10"` matches `10150`, not `11120`)
- **Browse all products** from the list icon
- **Add to cart dialog** — set quantity, **editable selling price**, and **discount %** when adding
- **Edit cart item** — tap the price line in cart to change quantity, price, or discount
- **Add new item** (not in inventory) — enter name, optional barcode, unit, qty, price, discount, **GST % (default 5%)**; saves to **Inventory** and adds to cart
- Customer selection, payment modes, real-time GST summary (Gross Total excl. GST, CGST/SGST)
- **Whole-rupee rounding** — all prices round to nearest rupee, displayed with `.00`

### Inventory & Barcodes
- Product CRUD, stock tracking, low stock alerts (default minimum stock: **0**)
- **CODE128 product labels (2" × 1.5")** — MRP, discount %, **SRT PRICE**, barcode, product name
- **Dual printers:** receipt **80 mm** (bills) and label **Posiflow P58D** (labels only) — separate Bluetooth connections in Settings
- **Label copies:** print 1–999 identical labels per job (gap-sensor aligned)
- View/print/share labels from Inventory; billing scanner reads **CODE128 barcode** on label

### Bills & Receipts
- 4-digit invoice numbers (`0001`, `0002`, …)
- **Custom footer** from Settings (left-aligned on print/PDF)
- **Invoice QR code** on each bill — footer text on the **left**, QR on the **right**
- QR payload: `INV:<no>|SC:<shop>|AMT:<total>|DT:<date>`
- PDF and thermal receipt: price × quantity with **Rs** and unit; **TOTAL DISCOUNT**; **Total Items** after Gross Total
- Bills list shows amount **excluding GST** per invoice
- Bluetooth thermal print (SPP preferred, BLE fallback); shop logo on receipts

### Reports
- **Sales report** — separate totals: **Total Sales (excl. GST)**, **Total GST**, **Total (incl. GST)**, invoice count, average sale (excl. GST)
- **Excel export** — Subtotal column is **excluding GST**; GST and Total columns unchanged
- GST report and analytics charts

### Settings & Admin
- **Shop details** — summary card + **Edit Shop Details** screen (logo, address, **shop code**, **phone optional**, email, GSTIN, footer)
- **Dual Bluetooth printers** — receipt (80 mm) and label (2"×1.5"), each with scan/connect/test/disconnect
- Google Drive backup, user management (admin)

### Other
- Per-product **GST %** from Inventory; GST applied **after** item discount
- Multi-user login with roles and biometric authentication
- Customer database with purchase history

## Requirements

- Flutter SDK 3.0.0 or higher
- Android Studio or VS Code with Flutter extensions
- Android 7.0 (API 24) or higher
- Camera for barcode scanning
- Bluetooth 4.0+ for printer connectivity (optional)

## Getting Started

### 1. Install Flutter

Follow the official Flutter installation guide: https://flutter.dev/docs/get-started/install

### 2. Clone and Setup

```bash
cd bill-service
flutter pub get
```

### 3. Generate Database Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the App

```bash
flutter run
```

### 5. Build Production Package

```bash
flutter build apk --release
```

## Default Login

- **Username:** `admin`
- **Password:** `admin123`

## Documentation

| Document | Contents |
|----------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, flows, data model |
| [PRINTING_GUIDE.md](PRINTING_GUIDE.md) | Labels, receipts, invoice QR, gap sensor, rounding |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Manual test cases (physical device) |
| [EMULATOR_TESTING_GUIDE.md](EMULATOR_TESTING_GUIDE.md) | Emulator setup and limitations |
| [MANUAL_BILLING_GUIDE.md](MANUAL_BILLING_GUIDE.md) | Day-to-day billing workflow |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | Feature checklist |
| [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) | Setup and folder structure |
| [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md) | Release APK / signing |
| [DATA_AND_SECURITY.md](DATA_AND_SECURITY.md) | Database location and security |
| [MANUAL_GRADLE_INSTALL.md](MANUAL_GRADLE_INSTALL.md) | Gradle install troubleshooting |

## Quick Reference

| Task | Path |
|------|------|
| Print bill | Billing → Print Bill |
| Print product label | Inventory → barcode icon → Print |
| Connect printers | Settings → Receipt / Label printer cards |
| Edit shop code | Settings → Edit Shop Details |
| Scan at billing | Billing → scan CODE128 on label |
