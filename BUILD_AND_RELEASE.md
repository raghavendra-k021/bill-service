# Building a Production Package for Installation on Devices

**Project folder:** `bill-service`

This guide explains how to create a **release** build of the Billing Service Android app that you can install on physical devices (phones/tablets) or distribute via Play Store.

---

## Prerequisites

1. **Flutter SDK** installed and `flutter doctor` passing (tested with **Flutter 3.47.4** / Dart 3.13)
2. **Java 17** (or newer that Flutter selects) — `java -version`
3. **Android SDK** (API 24+) and Android toolchain
4. **Code generation** already run:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

### Android build toolchain (current working copy)

These versions are what a successful `flutter build apk --release` used with Flutter 3.47. They live in Git; the APK itself does not.

| Tool | Version | Where it is set |
|------|---------|-----------------|
| Gradle | **8.14** | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | **8.11.1** | `android/settings.gradle`, `android/build.gradle` |
| Kotlin | **2.2.20** | same two files (`ext.kotlin_version` / plugin id) |
| Gradle JVM heap | **8G** | `android/gradle.properties` (`org.gradle.jvmargs`) |
| minSdk / compileSdk / targetSdk | 24 / 36 / 36 | `android/app/build.gradle` |

Do **not** commit `*.apk`, `build/`, `.dart_tool/`, `android/.gradle/`, `android/local.properties`, or keystores. See `.gitignore`.

---

## Option A: Quick Installable APK (Debug-Signed, for Testing)

Use this to quickly get an APK you can install on devices **without** creating a keystore. Not for Play Store.

```bash
cd bill-service
flutter build apk
```

- **Output:** `build/app/outputs/flutter-apk/app-release.apk`
- **Install on device:** Copy the APK to the device and open it (enable "Install from unknown sources" if prompted), or use:
  ```bash
  flutter install --release
  ```
  (with device connected via USB)

---

## Option B: Production APK (Release-Signed, for Distribution)

For a proper production build you must **sign** the app with your own keystore.

### Step 1: Create a Keystore (One-Time)

Run this in a terminal (Windows PowerShell or Command Prompt). Replace `your-keystore-name` and passwords with your own. **Keep the keystore and passwords safe**; you need them for all future updates.

```bash
keytool -genkey -v -keystore c:\path\to\your\keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias billing-service
```

- You will be asked for a keystore password and key password. Remember them.
- Store the `.jks` file in a safe place (e.g. `android/app/upload-keystore.jks` or outside the project). **Do not commit it to Git.**

### Step 2: Create `key.properties`

In the project root (`bill-service`), create a file named **`key.properties`** with:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=billing-service
storeFile=path/to/your/keystore.jks
```

- Use the same passwords and alias you used when creating the keystore.
- `storeFile` can be relative to the project root, e.g. `android/app/upload-keystore.jks`, or an absolute path like `c:\\keys\\billing-service.jks`.

**Important:** `key.properties` contains secrets. It is already in `.gitignore` — do not commit it.

### Step 3: Configure Signing in `android/app/build.gradle`

The project is set up to read `key.properties` and use it for release builds. Ensure `android/app/build.gradle` contains the signing block (see below). If you added it yourself, it should look like this (the file may already have been updated):

- At the top (after the `def flutterVersionName` block), load `key.properties`:
  ```groovy
  def keystoreProperties = new Properties()
  def keystorePropertiesFile = rootProject.file('key.properties')
  if (keystorePropertiesFile.exists()) {
      keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
  }
  ```
- Inside `android { }`, add `signingConfigs` and use it in `buildTypes.release`:
  ```groovy
  signingConfigs {
      release {
          keyAlias keystoreProperties['keyAlias']
          keyPassword keystoreProperties['keyPassword']
          storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
          storePassword keystoreProperties['storePassword']
      }
  }
  buildTypes {
      release {
          signingConfig signingConfigs.release
      }
  }
  ```

### Step 4: Build Release APK

```bash
cd bill-service
flutter build apk --release
```

- **Output:** `build/app/outputs/flutter-apk/app-release.apk`
- This APK is signed and can be distributed (e.g. direct install on devices, or sideloading).

### Step 5: Install on Devices

**Method 1 – USB**
- Enable **Developer options** and **USB debugging** on the device.
- Connect the device, then run:
  ```bash
  flutter install --release
  ```

**Method 2 – Copy APK**
- Copy `build/app/outputs/flutter-apk/app-release.apk` to the device (email, cloud, USB).
- On the device, open the APK file and follow the install prompts. You may need to allow "Install from unknown sources" for the file manager or browser.

**Running via `flutter run`:** The app deployed with `flutter run` is also installed on the device and works standalone (disconnect and use from the app drawer). To remove it: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only`.

---

## Option C: Android App Bundle (AAB) for Google Play Store

For **Play Store** you must upload an **Android App Bundle** (`.aab`), not an APK. Play then generates optimized APKs for different devices.

1. **Signing:** Use the same keystore and `key.properties` as in Option B (Step 1–3).
2. **Build AAB:**
   ```bash
   cd bill-service
   flutter build appbundle --release
   ```
3. **Output:** `build/app/outputs/bundle/release/app-release.aab`
4. Upload `app-release.aab` in **Google Play Console** (App releases → Production or Testing).

---

## Build Variants Summary

| Command | Output | Use case |
|--------|--------|----------|
| `flutter build apk` | `app-release.apk` (debug-signed if no key.properties) | Quick testing, direct install |
| `flutter build apk --release` (with signing) | `app-release.apk` (release-signed) | Production APK for devices |
| `flutter build appbundle --release` (with signing) | `app-release.aab` | Google Play Store |

---

## Version and Build Number

Set in **`pubspec.yaml`**:

```yaml
version: 1.0.0+1
```

- **1.0.0** = versionName (shown to users)
- **1** = versionCode (integer for Play Store; increase for each upload)

After changing, run the build again.

---

## Troubleshooting

- **"key.properties not found" or signing errors:** Ensure `key.properties` exists in the project root and paths/passwords are correct. Use double backslashes in Windows paths in `key.properties` (e.g. `c:\\keys\\app.jks`).
- **"Gradle version is lower than Flutter's minimum supported version of 8.14.0":** The wrapper must be Gradle **8.14** (see the toolchain table). Older 8.9 / 8.11.1 wrappers fail on Flutter 3.47.
- **"Java heap space" / JetifyTransform OOM:** `android/gradle.properties` must give Gradle enough memory (`-Xmx8G`). Stop daemons after changing it: `cd android && ./gradlew --stop`.
- **SSL / `PKIX path building failed` while downloading Gradle:** See **[MANUAL_GRADLE_INSTALL.md](MANUAL_GRADLE_INSTALL.md)**.
- **Install blocked on device:** Enable "Install from unknown sources" (or "Install unknown apps") for the app used to open the APK.

---

## Security Checklist

- [ ] Never commit `key.properties` or `.jks` / `.keystore` files to Git (they are in `.gitignore`)
- [ ] Back up your keystore and passwords securely; losing them prevents you from updating the same app on Play Store
- [ ] For Play Store, prefer **Play App Signing** and upload your AAB; Google can manage the final signing key

Once the release build succeeds, use **Option B** for production APKs and **Option C** for Play Store; install on devices using the steps in Option B, Step 5.
