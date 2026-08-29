# Setup Instructions

## Prerequisites

1. Install Flutter SDK (3.0.0 or higher)
2. Install Android Studio or VS Code with Flutter extensions
3. Set up Android SDK (API 24 or higher)

## Setup Steps

### 1. Install Dependencies

```bash
cd textile_billing_android
flutter pub get
```

### 2. Generate Database Code

The Drift database requires code generation. Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate the following files:
- `lib/database/app_database.g.dart`
- `lib/database/daos/*.g.dart`

### 3. Configure Android

The Android configuration is already set up in:
- `android/app/src/main/AndroidManifest.xml` - Permissions and app configuration
- `android/app/build.gradle` - Build configuration
- `android/build.gradle` - Project-level configuration

### 4. Run the App

```bash
flutter run
```

The app is installed on the connected device and **works standalone** (you can disconnect the device and use it from the app drawer). To uninstall from the connected device: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only`.

## Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

**Important:** Change the default password after first login!

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── database/                 # Drift database (requires code generation)
│   ├── app_database.dart
│   ├── daos/                 # Data Access Objects
│   └── tables/               # Database table definitions
├── screens/                   # UI screens
│   ├── login/
│   ├── dashboard/
│   ├── billing/
│   ├── inventory/             # Includes barcode label screen
│   ├── customers/
│   ├── bills/
│   ├── reports/
│   └── settings/
├── services/                 # Business logic
├── utils/                    # Utilities
└── widgets/                  # Reusable widgets
```

## Notes

- The database will be automatically created on first run
- Default admin user is created automatically
- Camera permission is required for barcode scanning
- Bluetooth permission is required for printer connectivity (optional)
- Barcode labels can be viewed and printed from Inventory (per-product barcode icon) or from Edit Product; PDF share works without a printer

## Troubleshooting

### Build Runner Issues

If code generation fails:
1. Delete `lib/database/*.g.dart` files
2. Run `flutter clean`
3. Run `flutter pub get`
4. Run `flutter pub run build_runner build --delete-conflicting-outputs`

### Android Build Issues

If Android build fails:
1. Ensure Android SDK is properly configured
2. Check `android/local.properties` has correct `sdk.dir` path
3. Ensure minimum SDK is 24 (Android 7.0)
