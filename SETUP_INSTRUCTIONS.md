# Setup Instructions

**Project folder:** `bill-service` (working copy)

## Prerequisites

1. Install Flutter SDK (3.0.0 or higher; release APK tested with **Flutter 3.47.4**)
2. Install **Java 17** (required by Flutter’s Android toolchain)
3. Install Android Studio or VS Code with Flutter extensions
4. Set up Android SDK (API 24 or higher)

## Setup Steps

### 1. Install Dependencies

```bash
cd bill-service
flutter pub get
```

### 2. Generate Database Code

The Drift database requires code generation. Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/database/app_database.g.dart`
- `lib/database/daos/*.g.dart`

Re-run after schema changes (e.g. shop logo, footer columns).

### 3. Configure Android

Already configured in:
- `android/app/src/main/AndroidManifest.xml` — permissions (camera, Bluetooth, storage)
- `android/app/build.gradle` — minSdk 24, compileSdk/targetSdk 36, signing
- `android/settings.gradle` / `android/build.gradle` — AGP **8.11.1**, Kotlin **2.2.20**
- `android/gradle/wrapper/gradle-wrapper.properties` — Gradle **8.14**
- `android/gradle.properties` — 8G heap (needed for release Jetifier)

### 4. Run the App

```bash
flutter run
```

The app installs on the device and **works standalone**. To uninstall: `adb uninstall com.billingservice.app`

## Default Login Credentials

- **Username:** `admin`
- **Password:** `admin123`

Change the default password after first login.

## Project Structure

```
bill-service/lib/
├── main.dart
├── models/
├── database/          # Drift — requires build_runner
├── screens/
│   ├── billing/       # POS, cart, add/edit item dialogs
│   ├── inventory/     # Products, barcode label screen
│   ├── bills/         # Bill list & detail (PDF/print)
│   ├── reports/       # Sales, GST, analytics
│   └── settings/      # Shop details, printer, backup
├── services/          # print_service, report_service, billing, …
├── utils/
└── widgets/
```

## Feature Notes

| Area | Notes |
|------|--------|
| **Billing** | Editable price/discount; add new items to inventory; **CODE128 label scan** adds to cart |
| **Labels** | 2"×1.5" CODE128 layout; **dual printers** (receipt 80 mm + Posiflow P58D); copy count 1–999 |
| **Receipts** | Custom footer (left) + invoice QR (right); whole-rupee rounding with `.00` |
| **Shop code** | Edit Shop Details → used on label price line + invoice QR `SC:` field (default SRT) |
| **Reports** | Sales split excl/incl GST; Excel subtotal excl. GST |
| **Shop phone** | Optional in Edit Shop Details |
| **GST on quick-add** | Default **5%**; change in dialog or Inventory later |

## Troubleshooting

### Build Runner Issues

1. Delete `lib/database/*.g.dart` if corrupted
2. `flutter clean`
3. `flutter pub get`
4. `dart run build_runner build --delete-conflicting-outputs`

### Android Build Issues

1. Check Android SDK in `flutter doctor`
2. Verify `android/local.properties` → `sdk.dir` (do not commit this file)
3. Minimum SDK: 24; Java 17
4. If Flutter reports Gradle < 8.14.0 or AGP too old, see [BUILD_AND_RELEASE.md](BUILD_AND_RELEASE.md)
5. Do not commit APKs or `build/` — they are gitignored

### Gradle SSL Errors

See **[MANUAL_GRADLE_INSTALL.md](MANUAL_GRADLE_INSTALL.md)** (Gradle **8.14**, not 8.9 / 8.11.1)
