# Billing Service Android Application

A comprehensive Android mobile billing application for any type of business, built with Flutter, featuring camera-based barcode scanning, Bluetooth thermal printer support, inventory management, GST calculation, customer database, multi-user authentication, sales reports, and Google Drive cloud backup.

## Features

- 🛒 **Point of Sale (POS)**: Complete billing system with camera-based barcode scanning
- 📦 **Inventory Management**: Product CRUD, stock tracking, low stock alerts (default minimum stock: 0)
- 🏷️ **Barcode Generation & Printing**: Code 128 labels; print to Bluetooth thermal printer or save/share as PDF
- 👥 **Customer Management**: Customer database with purchase history
- 📊 **Reports & Analytics**: Sales reports, GST reports with charts
- 🧾 **GST**: GST % per product (from Inventory); GST applied after discount; Gross Total shown without GST; CGST/SGST displayed
- 🖨️ **Receipt Printing**: Bluetooth thermal printer (receipts and barcode labels)
- 📄 **Custom Footer**: Set a custom footer message in Settings; it appears on invoice PDFs and thermal receipts
- 📋 **Invoice format**: 4-digit invoice numbers (0001, 0002, …); PDF/print show price × quantity with Rs and unit per item; Total Items on next line after Gross Total
- 🔍 **Product search**: Search by barcode or name **starts with** (e.g. "10" matches 10150, not 11120)
- 📊 **Bills list**: Shows total amount **excluding GST** per invoice
- 👤 **Multi-user Login**: Role-based access control with biometric authentication
- ☁️ **Cloud Backup**: Google Drive integration with scheduled backups

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
cd textile_billing_android
flutter pub get
```

### 3. Generate Database Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Run the App

```bash
flutter run
```

### 5. Build Production Package (Install on Devices)

To create an APK or AAB for installation on devices or Play Store, see **[BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md)**.

**Note:** After deploying with `flutter run`, the app is installed on the device and works standalone (you can disconnect the device). To uninstall from the connected device: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only`.

## Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

**Important:** Change the default password after first login!

## Usage (Barcode Labels)

- **Inventory** → tap the barcode icon (📷) next to a product to open the barcode label screen.
- **Edit Product** → when editing a product that has a barcode, use the app bar barcode icon to view/print.
- On the barcode screen: **Print to Bluetooth Printer** (requires a printer connected in Settings) or **Share / Save as PDF** to save or share the label.

## Project Structure

```
textile_billing_android/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   ├── database/              # Drift database
│   ├── screens/               # UI screens (billing, inventory, barcode, bills, reports, etc.)
│   ├── services/              # Business logic (billing, print, backup, etc.)
│   ├── utils/                 # Utilities
│   └── widgets/               # Reusable widgets
├── android/                   # Android native code
├── IMPLEMENTATION_STATUS.md   # Implementation status and checklist
├── TESTING_GUIDE.md           # Testing instructions
├── SETUP_INSTRUCTIONS.md      # Setup and run steps
└── pubspec.yaml               # Dependencies
```

## License

This project is open source and available for commercial use.
