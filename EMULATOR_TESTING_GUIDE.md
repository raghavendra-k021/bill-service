# Testing on Android Emulator - Complete Guide

**Project folder:** `bill-service` (working copy)

## ✅ Yes, the app can be tested on Android Emulator!

Most features work on emulator. **Camera scan** (label CODE128 / barcode) and **Bluetooth print** (receipt 80 mm + label 2×1.5 in) need a physical device for full testing.

### Recent features to verify on device

- **CODE128 product labels** (2"×1.5") — MRP, -10%, SRT PRICE, barcode; billing scans barcode
- **Dual Bluetooth printers** — receipt (80 mm bills) and label (P58D) as separate connections in Settings
- **Label copy count** — print multiple identical labels in one job
- **Billing scan** — scan label **CODE128 barcode** → lookup product → auto-add to cart at SRT PRICE
- **Shop code** — Settings → Edit Shop Details (default **SRT**); reprint labels after change
- **Invoice QR** on receipt (footer left, QR right)
- **Add new item** from billing → inventory + cart
- **Sales report** excl/incl GST split and Excel export

---

## Prerequisites

1. **Android Studio** installed
2. **Android SDK** configured
3. **Flutter SDK** installed and configured
4. **At least 4GB RAM** available (8GB recommended)

---

## Testing on Physical Android Device (e.g. Android 15)

To run the app on a **physical phone/tablet** (including Android 15) so it shows in VS Code/Cursor and `flutter devices`:

### 1. Enable Developer options on the device

1. Open **Settings** → **About phone**
2. Tap **Build number** 7 times until you see "You are now a developer"

### 2. Turn on USB debugging

1. Go to **Settings** → **System** → **Developer options** (or **Settings** → **Developer options** on some devices)
2. Enable **Developer options** if it’s a toggle
3. Enable **USB debugging**
4. If you see **Wireless debugging**, you can use that later; for first-time setup, USB is easier

### 3. Connect the device

1. Connect the phone to the PC with a **USB data cable** (not charge-only)
2. On the phone, when prompted **"Allow USB debugging?"** tap **Allow** (and optionally **Always allow from this computer**)
3. Set USB mode to **File transfer / MTP** or **PTP** if asked (not "Charge only")

### 4. Install USB driver (Windows only)

- **Samsung:** Install [Samsung USB Driver](https://developer.samsung.com/android-usb-driver)
- **Google Pixel:** Usually works with [Google USB Driver](https://developer.android.com/studio/run/win-usb) or Windows default
- **Other brands:** Install the manufacturer’s USB driver, or use **Google USB Driver** from SDK Manager in Android Studio

### 5. Verify the device is detected

In a terminal (VS Code/Cursor terminal or PowerShell):

```bash
flutter devices
```

You should see your phone listed, for example:

```
Android SDK built for arm64 (mobile) • XXXXXX • android-arm64 • Android 15 (API 35)
```

If the device does **not** appear:

- Run: `adb devices`. If it shows "unauthorized", unlock the phone and accept the USB debugging prompt again
- Try another USB port (preferably USB 2.0) or another cable
- Restart ADB: `adb kill-server` then `adb start-server`, then `flutter devices` again

### 6. Run the app on the device

1. In VS Code/Cursor: press **F5** or use **Run → Start Debugging**, or
2. In terminal from the project folder:

```bash
cd c:\Users\raghak\workspace_raghak\bill-service
flutter run
```

If multiple devices are connected, choose the Android 15 device when prompted, or run:

```bash
flutter run -d <device_id>
```

(Use the device ID shown in `flutter devices`.)

**After deployment:** The app is installed on the device and **works standalone** (you can disconnect the device and use it from the app drawer). To uninstall from the connected device: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only`.

---

## Step 1: Create Android Emulator

### 1.1 Open Android Studio

1. Launch **Android Studio**
2. Click **More Actions** → **Virtual Device Manager**
   - Or go to: **Tools** → **Device Manager**

### 1.2 Create New Virtual Device

1. Click **Create Device** button
2. Select a device definition:
   - **Recommended:** Pixel 5 or Pixel 6
   - **Alternative:** Any phone with API 24+
   - Click **Next**

3. Select System Image:
   - **Recommended:** 
     - **API Level 33** (Android 13) - Latest
     - **API Level 30** (Android 11) - Stable
     - **API Level 24** (Android 7.0) - Minimum
   - Click **Download** if image not installed
   - Click **Next**

4. Configure AVD:
   - **AVD Name:** `Billing_Service_Test` (or any name)
   - **Startup orientation:** Portrait
   - **Graphics:** Automatic (or Hardware - GLES 2.0)
   - Click **Finish**

### 1.3 Verify Emulator Created

- You should see your emulator in the device list
- Status should show as "Cold Boot" or "Stopped"

---

## Step 2: Start the Emulator

### Method 1: From Android Studio

1. In **Device Manager**, click **Play** button (▶) next to your emulator
2. Wait for emulator to boot (2-5 minutes first time)
3. Emulator window opens showing Android home screen

### Method 2: From Command Line

```bash
# List available emulators
emulator -list-avds

# Start specific emulator
emulator -avd Billing_Service_Test
```

**Note:** First boot takes longer. Subsequent boots are faster.

---

## Step 3: Verify Emulator Connection

### 3.1 Check Flutter Recognizes Emulator

```bash
flutter devices
```

**Expected Output:**
```
2 connected devices:

sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64  • Android 13 (API 33) (emulator)
Chrome (web)                • chrome       • web-javascript • Google Chrome
```

### 3.2 Verify Emulator is Running

- Emulator window should be open
- Android home screen should be visible
- No error messages

---

## Step 4: Run the Application

### 4.1 Navigate to Project

```bash
cd c:\Users\raghak\workspace_raghak\bill-service
```

### 4.2 Generate Database Code (If Not Done)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 4.3 Run on Emulator

```bash
flutter run
```

**What Happens:**
1. Flutter detects the emulator
2. Compiles the app (first time: 2-5 minutes)
3. Installs app on emulator
4. Launches the app automatically

**Expected Result:**
- App opens on emulator
- Login screen appears
- Ready to test!

---

## Step 5: Testing on Emulator

### ✅ Features That Work Perfectly

1. **Login & Authentication**
   - Username/password login ✅
   - Remember me ✅
   - **Note:** Biometric may not work (depends on emulator)

2. **Dashboard**
   - All summary cards ✅
   - Navigation ✅
   - Low stock alerts ✅

3. **Inventory Management**
   - Add/Edit/Delete products ✅
   - Search products ✅
   - Stock management ✅
   - **Barcode label screen** — preview layout, set copy count, Share/Save as PDF ✅
   - Edit **shop code** via Settings → Edit Shop Details (admin) ✅
   - All CRUD operations ✅

4. **Customer Management**
   - Add/Edit/Delete customers ✅
   - Search customers ✅
   - All features ✅

5. **Billing (Manual)**
   - Product search by name ✅
   - Browse all products ✅
   - Add products to cart ✅
   - Cart management ✅
   - Customer selection ✅
   - Payment modes ✅
   - GST calculation ✅
   - Save bills ✅

6. **View Bills**
   - List all bills ✅
   - Date filtering ✅
   - Bill details ✅
   - All features ✅

7. **Reports**
   - Sales reports ✅
   - GST reports ✅
   - Analytics ✅
   - Excel export ✅

8. **Settings**
   - Shop details + **shop code** (used on invoice QR; default **SRT**) ✅
   - Dual printer UI (connect/test cards) — pairing not on emulator ⚠️
   - User management ✅
   - All other settings ✅

### ⚠️ Features with Limitations

1. **Camera Scanner (CODE128 / Barcode)**
   - **Status:** Limited on emulator
   - **Workaround:** Use manual search, browse products, or tap items in list
   - **Note:** Scanning printed **label barcode** at billing needs a physical device camera for real testing

2. **Bluetooth Printers (Dual)**
   - **Status:** Not available on emulator
   - **Receipt printer (80 mm):** bills, test receipt, invoice QR footer — physical device only
   - **Label printer (2"×1.5" gap labels, e.g. Posiflow P58D):** product labels, test label, copy count — physical device only
   - **Workaround on emulator:** Open **Barcode / Label** screen → preview layout → **Share / Save as PDF** (respects copy count as multiple PDF pages)
   - **Note:** Pair both printers in Android Bluetooth settings, then connect each separately in **Settings → Printer Settings**

3. **Google Drive Backup**
   - **Status:** Works if internet available
   - **Note:** Requires Google account sign-in

---

## Step 6: Testing Workflow on Emulator

### Complete Test Flow:

1. **Login**
   ```
   Username: admin
   Password: admin123
   ```

2. **Add Products**
   - Go to Inventory
   - Add 3-5 test products with **default discount %** (used on labels)
   - Example:
     - Product 1: "Cotton Saree", MRP ₹500, discount 10%
     - Product 2: "Silk Fabric", MRP ₹1200, discount 5%
     - Product 3: "Kanchipuram Saree", MRP ₹10000, discount 10% → NET ₹9000 on label

3. **Preview label (emulator)**
   - Inventory → barcode icon on a product
   - Expected: MRP (left), -10% (right), **SRT PRICE**, CODE128 barcode, product name
   - Set **Number of labels** → Share PDF to verify layout (optional)

4. **Add Customer**
   - Go to Customers
   - Add a test customer

5. **Create Bill**
   - Go to Billing
   - Tap "Browse All Products" (list icon)
   - Add products to cart
   - Select customer
   - Set payment mode
   - Save bill

6. **View Bill**
   - Go to Bills
   - Open the bill you just created
   - Verify all details

7. **Generate Report**
   - Go to Reports
   - Select date range
   - View sales and GST reports

**All of this works perfectly on emulator!**

---

## Step 7: Emulator-Specific Tips

### 7.1 Performance Optimization

**If emulator is slow:**

1. **Increase RAM:**
   - Edit AVD → Show Advanced Settings
   - RAM: 2048 MB or higher
   - VM heap: 512 MB

2. **Use Hardware Acceleration:**
   - Graphics: Hardware - GLES 2.0
   - Enable hardware acceleration in BIOS

3. **Close Other Applications:**
   - Free up system resources

### 7.2 Camera Testing (Optional)

**To test camera on emulator:**

1. **Use Webcam:**
   - Some emulators can use webcam as camera
   - Settings → Extended Controls → Camera
   - Select webcam

2. **Or Skip Camera:**
   - Use manual product search instead
   - All features work without camera

### 7.3 Keyboard Shortcuts

**Useful emulator shortcuts:**
- `Ctrl + M` - Open menu
- `F11` - Toggle fullscreen
- `Ctrl + F` - Toggle zoom
- `Back` - Android back button
- `Home` - Android home button

---

## Step 8: Common Issues & Solutions

### Issue 1: Emulator Won't Start

**Error:** "HAXM not installed" or similar

**Solution:**
```bash
# Check if HAXM is installed
# If not, install from Android Studio SDK Manager
# Or use ARM-based emulator instead
```

### Issue 2: Flutter Can't Find Emulator

**Error:** `flutter devices` shows no emulator

**Solution:**
1. Ensure emulator is fully booted (wait for home screen)
2. Check ADB connection:
   ```bash
   adb devices
   ```
3. Restart ADB:
   ```bash
   adb kill-server
   adb start-server
   ```

### Issue 3: App Crashes on Launch

**Error:** App crashes immediately

**Solution:**
1. Check logs:
   ```bash
   flutter run --verbose
   ```
2. Ensure database code is generated
3. Check for compilation errors

### Issue 4: Slow Performance

**Error:** App is laggy

**Solution:**
1. Increase emulator RAM
2. Use x86/x86_64 system image (faster than ARM)
3. Close unnecessary apps
4. Enable hardware acceleration

### Issue 5: Database Errors

**Error:** "Table doesn't exist"

**Solution:**
1. Uninstall app from emulator
2. Reinstall:
   ```bash
   flutter run
   ```
3. Database will be recreated

### Issue 6: Java Version Incompatibility

**Error:** `Unsupported class file major version 65` or `Gradle version is incompatible with Java version`

**Solution:**
The project has been configured to use Gradle 8.9 which supports Java 8-21. If you still see this error:
1. Check your Java version: `java -version`
2. Ensure you're using Java 8-21 (Gradle 8.9 supports up to Java 21)
3. If using Java 22+, you may need to upgrade to Gradle 8.10+ or use Java 21
4. Clear Gradle cache if you see version mismatches:
   ```bash
   flutter clean
   cd android
   .\gradlew clean
   cd ..
   ```

### Issue 6b: Android Gradle Plugin Version Too Old

**Error:** `Your project's Android Gradle Plugin version (8.1.0) is lower than Flutter's minimum supported version (8.1.1)`

**Solution:**
The AGP version has been updated to 8.1.4 in:
- `android/settings.gradle` - Updated plugin version
- `android/build.gradle` - Updated classpath version

If you see this error again, update both files to use AGP 8.1.4 or higher.

### Issue 6a: Flutter Doctor Warnings

**Warning:** `cmdline-tools component is missing` or `Android license status unknown`

**Note:** These are warnings, not errors. Your app can still run on the emulator.

**To fix (optional):**
1. **Accept Android licenses:**
   ```bash
   flutter doctor --android-licenses
   ```
   Press `y` to accept all licenses.

2. **Install cmdline-tools (optional):**
   - Open Android Studio
   - Go to **Tools** → **SDK Manager**
   - Under **SDK Tools** tab, check **Android SDK Command-line Tools**
   - Click **Apply** to install

### Issue 7: SSL Certificate Error (Gradle Download)

**Error:** `PKIX path building failed: unable to find valid certification path`

**Solution 1: Manual Gradle Installation (Recommended)**

**Option A: Use the installation script (Easiest)**
1. Download Gradle 8.9 manually (supports Java 21):
   - Visit: https://services.gradle.org/distributions/gradle-8.9-all.zip
   - Save it to your Downloads folder or Desktop
2. Run the installation script:
   ```bash
   install_gradle_8.9.bat
   ```
   The script will automatically find and install Gradle 8.9 to the correct location (hash: `6m0mbzute7p0zdleavqlib88a`).

**Option B: Manual installation**
1. Download Gradle 8.9:
   - Visit: https://services.gradle.org/distributions/gradle-8.9-all.zip
   - Download and save the zip file
2. Extract the zip file (you'll see a `gradle-8.9` folder inside)
3. Find the hash directory (run `flutter run` once to see it in the error, or check `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.9-all\`)
4. Copy the entire `gradle-8.9` folder contents to the hash directory's `gradle-8.9\` subfolder
5. Verify: The folder should contain `bin\gradle.bat`
6. Run: `flutter run`

**Solution 2: Use Helper Script**
Try the batch script that disables SSL certificate revocation checking:
```bash
run_with_ssl_fix.bat
```

**Solution 3: Set Environment Variables**
Before running `flutter run`, set:
```powershell
$env:GRADLE_OPTS="-Dcom.sun.net.ssl.checkRevocation=false"
$env:JAVA_OPTS="-Dcom.sun.net.ssl.checkRevocation=false"
flutter run
```

**Solution 4: Corporate Proxy Configuration**
If behind a corporate proxy, configure proxy settings in `android/gradle.properties`:
```properties
systemProp.http.proxyHost=your.proxy.com
systemProp.http.proxyPort=8080
systemProp.https.proxyHost=your.proxy.com
systemProp.https.proxyPort=8080
```

---

## Step 9: Quick Testing Commands

### Run on Specific Emulator

```bash
# List devices
flutter devices

# Run on specific device
flutter run -d emulator-5554
```

### Hot Reload

While app is running:
- Press `r` - Hot reload (quick changes)
- Press `R` - Hot restart (full restart)
- Press `q` - Quit

### View Logs

```bash
# Run with verbose logging
flutter run --verbose

# View device logs
adb logcat
```

### Install APK Directly

```bash
# Build APK
flutter build apk --debug

# Install on emulator
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Step 10: Testing Checklist for Emulator

### Basic Functionality ✅

- [ ] App installs successfully
- [ ] App launches without crashes
- [ ] Login screen appears
- [ ] Can login with default credentials
- [ ] Dashboard loads correctly
- [ ] Navigation works (all screens)

### Core Features ✅

- [ ] Add products to inventory
- [ ] Search products
- [ ] Browse all products
- [ ] Add customers
- [ ] Create bills
- [ ] View bills
- [ ] Generate reports
- [ ] Barcode label preview (MRP, SRT PRICE, CODE128 layout)
- [ ] Label PDF share (optional; multi-page if copy count > 1)
- [ ] Shop code visible in Settings summary / Edit Shop Details

### Data Persistence ✅

- [ ] Products saved after app restart
- [ ] Bills saved after app restart
- [ ] Customers saved after app restart
- [ ] Settings saved after app restart

### UI/UX ✅

- [ ] All screens render correctly
- [ ] Buttons are clickable
- [ ] Forms work properly
- [ ] Lists scroll smoothly
- [ ] No UI glitches

---

## Comparison: Emulator vs Physical Device

| Feature | Emulator | Physical Device |
|---------|----------|----------------|
| **Core Features** | ✅ Full | ✅ Full |
| **Manual Billing** | ✅ Works | ✅ Works |
| **Product Search** | ✅ Works | ✅ Works |
| **Database** | ✅ Works | ✅ Works |
| **Reports** | ✅ Works | ✅ Works |
| **Camera / Barcode scan** | ⚠️ Limited | ✅ Full |
| **Receipt printer (80 mm)** | ❌ No | ✅ Works |
| **Label printer (2"×1.5")** | ❌ No | ✅ Works |
| **Label PDF preview** | ✅ Works | ✅ Works |
| **Performance** | ⚠️ Slower | ✅ Faster |
| **Testing Speed** | ✅ Fast setup | ⚠️ Slower setup |

**Conclusion:** Emulator is perfect for testing 95% of features!

---

## Recommended Emulator Configuration

### For Best Performance:

```
Device: Pixel 5 or Pixel 6
System Image: Android 11 (API 30) or Android 13 (API 33)
RAM: 2048 MB or higher
VM Heap: 512 MB
Graphics: Hardware - GLES 2.0
```

### For Compatibility Testing:

```
Device: Multiple devices (different screen sizes)
System Images: API 24, 30, 33
Test on each to ensure compatibility
```

---

## Summary

✅ **Yes, emulator testing is fully supported!**

**What Works:**
- All core features
- Manual product selection
- Complete billing flow
- Reports and analytics
- Database operations
- Settings and configuration

**What's Limited:**
- Camera / **label barcode** scan at billing (use manual search on emulator)
- Bluetooth printing — **two printers** (receipt + label); test on physical device

**Physical device only (recommended final test):**
- Connect **receipt** and **label** printers in Settings
- Print test receipt + test label
- Scan printed **label barcode** at billing → item auto-added at SRT PRICE

**Best Practice:**
- Use emulator for development and most testing
- Use physical device for final testing of hardware features

---

## Quick Start Commands

```bash
# 1. Start emulator (from Android Studio or command line)
emulator -avd Billing_Service_Test

# 2. Verify connection
flutter devices

# 3. Run app
cd bill-service
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**That's it! Your app is now running on emulator! 🚀**

---

**Happy Testing on Emulator! 📱**
