# Billing Service Android Application

A comprehensive Android mobile billing application for any type of business, built with Flutter. The **working copy** of this project is the **`bill-service`** directory (`com.billingservice.app`).

## Features

### Point of Sale (Billing)
- Camera-based **barcode scanning** — scan adds product to cart (stays on billing screen; no accidental exit)
- **Product search** by barcode or name **starts with** (e.g. `"10"` matches `10150`, not `11120`)
- **Browse all products** from the list icon
- **Add to cart dialog** — set quantity, **editable selling price**, and **discount %** when adding
- **Edit cart item** — tap the price line in cart to change quantity, price, or discount
- **Add new item** (not in inventory) — enter name, optional barcode, unit, qty, price, discount, **GST % (default 5%)**; saves to **Inventory** and adds to cart
- **Add new item** button in billing app bar; **Add as new item** when search/scan finds nothing
- Customer selection, payment modes, real-time GST summary (Gross Total excl. GST, CGST/SGST)

### Inventory & Barcodes
- Product CRUD, stock tracking, low stock alerts (default minimum stock: **0**)
- **Barcode labels** — Code 128 on screen and PDF; **Bluetooth print uses bitmap** (matches softcopy; fixes wrong numbers on thermal printers)
- View/print/share labels from Inventory or Edit Product

### Bills & Receipts
- 4-digit invoice numbers (`0001`, `0002`, …)
- **Custom footer** from Settings (left-aligned on print/PDF)
- **Invoice QR code** on each bill — footer text on the **left**, QR on the **right** (invoice no, amount, date)
- PDF and thermal receipt: price × quantity with **Rs** and unit; **TOTAL DISCOUNT**; **Total Items** after Gross Total
- Bills list shows amount **excluding GST** per invoice
- Bluetooth thermal print (SPP preferred, BLE fallback); shop logo on receipts

### Reports
- **Sales report** — separate totals: **Total Sales (excl. GST)**, **Total GST**, **Total (incl. GST)**, invoice count, average sale (excl. GST)
- **Excel export** — Subtotal column is **excluding GST**; GST and Total columns unchanged
- GST report and analytics charts

### Settings & Admin
- **Shop details** — summary card + **Edit Shop Details** screen (logo, address, **phone optional**, email, GSTIN, footer)
- Google Drive backup, Bluetooth printer pairing, user management (admin)

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

See **[BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md)**.

**Note:** Install over an existing app to keep the database. Uninstall only if you want a fresh DB: `adb uninstall com.billingservice.app`

## Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

**Important:** Change the default password after first login!

## Quick Usage

| Task | How |
|------|-----|
| Create bill | Dashboard → Billing → search/scan/browse → add items → Save Bill |
| Unknown barcode | Scan or search → **Add as new item** → fill form → added to inventory & cart |
| Edit price in cart | Tap **₹ price × qty** line on cart item |
| Barcode label | Inventory → barcode icon → Print or Share PDF |
| Shop footer & logo | Settings → **Edit Shop Details** |
| Sales report | Reports → Sales → date range → Download Excel |
| Receipt QR | Automatic on every PDF/thermal bill (footer left, QR right) |

## Project Structure

```
bill-service/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── database/              # Drift (run build_runner)
│   ├── screens/               # billing, inventory, bills, reports, settings, …
│   ├── services/              # billing, print, report, inventory, backup, …
│   ├── utils/
│   └── widgets/
├── android/
├── README.md
├── IMPLEMENTATION_STATUS.md
├── TESTING_GUIDE.md
├── SETUP_INSTRUCTIONS.md
├── BUILD_AND_RELEASE.md
├── MANUAL_BILLING_GUIDE.md
├── EMULATOR_TESTING_GUIDE.md
└── pubspec.yaml
```

## Documentation

| Document | Purpose |
|----------|---------|
| [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) | Install, code generation, run |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Full test checklist |
| [MANUAL_BILLING_GUIDE.md](MANUAL_BILLING_GUIDE.md) | Billing without scanner |
| [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md) | Release APK/AAB |
| [EMULATOR_TESTING_GUIDE.md](EMULATOR_TESTING_GUIDE.md) | Emulator & device testing |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture & flow diagrams |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | Feature list & status |
| [DATA_AND_SECURITY.md](DATA_AND_SECURITY.md) | Database location & backup |

## License

This project is open source and available for commercial use.
