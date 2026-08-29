# Testing Guide for Billing Service Android App

## Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Verify: `flutter --version`
   - If not installed: https://flutter.dev/docs/get-started/install

2. **Android Studio** or **VS Code** with Flutter extensions
   - Android Studio: https://developer.android.com/studio
   - VS Code: Install "Flutter" and "Dart" extensions

3. **Android Device or Emulator**
   - **Physical device:** Enable Developer Options and USB Debugging
   - **Emulator:** Create via Android Studio AVD Manager (Recommended for testing)
   - Minimum: Android 7.0 (API 24)
   
   **📱 For detailed emulator testing guide, see [EMULATOR_TESTING_GUIDE.md](EMULATOR_TESTING_GUIDE.md)**

4. **Check Flutter Setup**
   ```bash
   flutter doctor
   ```
   Ensure all checks pass (especially Android toolchain)

## Step 1: Initial Setup

### 1.1 Navigate to Project Directory
```bash
cd c:\Users\raghak\workspace_raghak\textile_billing_android
```

### 1.2 Install Dependencies
```bash
flutter pub get
```

### 1.3 Generate Database Code (CRITICAL)
This is **required** before running the app. Drift database needs code generation:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Expected Output:**
- Should generate `lib/database/app_database.g.dart`
- Should generate `lib/database/daos/*.g.dart` files
- If you see errors, see Troubleshooting section below

### 1.4 Verify Generated Files
Check that these files exist:
- `lib/database/app_database.g.dart`
- `lib/database/daos/user_dao.g.dart`
- `lib/database/daos/product_dao.g.dart`
- `lib/database/daos/customer_dao.g.dart`
- `lib/database/daos/invoice_dao.g.dart`

## Step 2: Run the Application

### 2.1 Connect Device/Emulator
- **Physical Device**: Connect via USB, enable USB debugging
- **Emulator**: Start from Android Studio AVD Manager

### 2.2 Verify Device Connection
```bash
flutter devices
```
You should see your device listed.

### 2.3 Run the App
```bash
flutter run
```

**First Run:**
- App will compile (may take 2-5 minutes)
- Database will be created automatically
- Default admin user will be created

## Step 3: Testing Checklist

### ✅ Test 1: Login Screen

**Test Cases:**
1. **Default Login**
   - Username: `admin`
   - Password: `admin123`
   - Expected: Should navigate to Dashboard

2. **Invalid Credentials**
   - Wrong username/password
   - Expected: Error message "Invalid username or password"

3. **Biometric Authentication** (if device supports)
   - Tap fingerprint icon
   - Expected: Biometric prompt appears
   - After authentication: Should login

4. **Remember Me**
   - Check "Remember me" checkbox
   - Expected: Should save credentials (if implemented)

**Expected Result:** ✅ Login successful, navigates to Dashboard

---

### ✅ Test 2: Dashboard

**Test Cases:**
1. **Summary Cards**
   - Check "Today's Sales" card
   - Check "Today's Invoices" card
   - Expected: Should show 0 initially (no sales yet)

2. **Low Stock Alert**
   - If products exist with low stock
   - Expected: Orange alert card appears

3. **Quick Actions**
   - Tap each icon (Billing, Inventory, Customers, etc.)
   - Expected: Should navigate to respective screens

4. **Drawer Menu**
   - Open drawer (hamburger menu)
   - Navigate to different screens
   - Expected: All menu items work

**Expected Result:** ✅ Dashboard displays correctly, navigation works

---

### ✅ Test 3: Inventory Management

**Test Cases:**
1. **Add Product**
   - Tap "+" icon
   - Fill form:
     - Barcode: `1234567890123`
     - Name: `Test Product`
     - Purchase Price: `100`
     - Selling Price: `150`
     - GST %: `5`
     - Current Stock: `50`
     - Min Stock Alert: `0` (default)
   - Tap "Add Product"
   - Expected: Product added, returns to list

2. **View Products**
   - Check product appears in list
   - Expected: Shows name, stock, price

3. **Search Products**
   - Type in search box
   - Expected: Filters products in real-time

4. **Barcode / Print Label**
   - Tap the barcode icon (📷) next to a product
   - Expected: Opens barcode label screen (name, price, Code 128 barcode)
   - Tap "Share / Save as PDF" → Expected: PDF shared or saved
   - Tap "Print to Bluetooth Printer" (if printer connected in Settings) → Expected: Label prints

6. **Edit Product**
   - Tap on a product
   - Modify fields
   - Tap "Update Product"
   - Expected: Changes saved
   - When editing a product with a barcode, app bar shows barcode icon → opens same barcode label screen

7. **Delete Product** (if implemented)
   - Long press or use delete button
   - Expected: Product removed

**Expected Result:** ✅ CRUD operations work correctly

---

### ✅ Test 3b: Barcode Label Screen

**Test Cases:**
1. **Open from Inventory**
   - Go to Inventory, tap barcode icon next to a product
   - Expected: Barcode screen shows product name, price, Code 128 barcode

2. **Share / Save as PDF**
   - On barcode screen, tap "Share / Save as PDF"
   - Expected: System share sheet opens; can save or share PDF

3. **Print to Bluetooth** (if printer connected in Settings)
   - Tap "Print to Bluetooth Printer"
   - Expected: Label sent to printer or error if not connected

4. **Open from Edit Product**
   - Edit a product that has a barcode; tap barcode icon in app bar
   - Expected: Same barcode screen opens

**Expected Result:** ✅ Barcode display and PDF share work; Bluetooth print works when printer is connected

---

### ✅ Test 4: Customer Management

**Test Cases:**
1. **Add Customer**
   - Tap "+" icon
   - Fill form:
     - Name: `John Doe`
     - Phone: `9876543210`
     - Email: `john@example.com`
     - Address: `123 Main St`
   - Tap "Add Customer"
   - Expected: Customer added

2. **Search Customers**
   - Type in search box
   - Expected: Filters customers

3. **Edit Customer**
   - Tap on customer
   - Modify details
   - Expected: Changes saved

**Expected Result:** ✅ Customer management works

---

### ✅ Test 5: Billing Screen (Main Feature)

**Test Cases:**
1. **Product Search**
   - Search by barcode or name **starts with** (e.g. "10" matches barcode 10150, not 11120; "sar" matches "saree")
   - Type in search box; tap on product
   - Expected: Added to cart

2. **Barcode Scanning**
   - Tap barcode scanner icon
   - Expected: Camera opens
   - Scan a barcode (or use test barcode)
   - Expected: Product found and added to cart

3. **Manual Barcode Entry**
   - Type barcode in search
   - Expected: Finds product by barcode

4. **Cart Management**
   - Add multiple products
   - Change quantities (+/- buttons)
   - Remove items (delete icon)
   - Expected: Cart updates correctly

5. **Customer Selection**
   - Open customer dropdown
   - Select a customer or "Walk-in Customer"
   - Expected: Customer selected

6. **Payment Mode**
   - Select payment mode (Cash, Card, UPI, etc.)
   - Expected: Mode selected

7. **Discount**
   - Enter discount percentage
   - Expected: Bill summary updates

8. **GST Calculation**
   - Add products (each product has a GST % in Inventory)
   - GST is applied **after** item discount; Gross Total shown **without** GST; CGST and SGST displayed
   - Expected: GST uses each product’s GST %; bill summary shows Gross Total (excl. GST), then CGST/SGST

9. **Save Bill**
   - Fill all details
   - Tap "Save Bill"
   - Expected: 
     - Bill saved successfully
     - Invoice number is 4-digit (e.g. 0001, 0002)
     - Cart cleared
     - Stock updated

**Expected Result:** ✅ Complete billing flow works

---

### ✅ Test 6: View Bills

**Test Cases:**
1. **View Bills List**
   - Navigate to Bills screen
   - Expected: Shows all saved bills; **amount per invoice is excluding GST**

2. **Date Filtering**
   - Tap calendar icon
   - Select date range
   - Expected: Filters bills by date

3. **Bill Details**
   - Tap on a bill
   - Expected: Shows:
     - Invoice number (4-digit, e.g. 0001)
     - Date
     - Items list (price × quantity unit)
     - Gross Total (without GST), CGST, SGST, Payment (no "Total GST" or "Total" line)

4. **Export PDF / Print**
   - Tap PDF or print icon
   - Expected: PDF/print shows **price × quantity with Rs and unit** per item; **Total Items** on next line after Gross Total; custom footer if set in Settings

**Expected Result:** ✅ Bills viewing works correctly

---

### ✅ Test 7: Reports & Analytics

**Test Cases:**
1. **Sales Report**
   - Navigate to Reports
   - Select "Sales" tab
   - Select date range
   - Expected: Shows:
     - Total sales
     - Invoice count
     - Average sale

2. **GST Report**
   - Select "GST" tab
   - Expected: Shows:
     - Total GST
     - CGST, SGST, IGST breakdown
     - Taxable amount

3. **Analytics**
   - Select "Analytics" tab
   - Expected: Shows charts/graphs

4. **Export to Excel**
   - Tap "Export to Excel" button
   - Expected: Excel file created

**Expected Result:** ✅ Reports generate correctly

---

### ✅ Test 8: Settings

**Test Cases:**
1. **Shop Details**
   - Enter shop information
   - Tap "Save Shop Details"
   - Expected: Settings saved

2. **Footer (bills & receipts)**
   - Enter a custom footer (e.g. "Thank you for your Business!" or "Exchange valid for 7 days from the billing date.")
   - Save shop details
   - Create or open a bill → view PDF or print receipt
   - Expected: Custom footer appears at bottom of invoice PDF and thermal receipt; if left empty, default "Thank you for your business!" is used

3. **Google Drive Backup**
   - Tap backup button
   - Sign in to Google (if not signed in)
   - Expected: Backup created and uploaded

4. **Printer Setup**
   - Tap "Scan for Printers"
   - Expected: Scans for Bluetooth printers
   - Select printer
   - Expected: Connects to printer

**Expected Result:** ✅ Settings work correctly

---

## Step 4: Integration Testing

### Test Complete Billing Flow

1. **Setup:**
   - Add at least 3 products to inventory
   - Add 1 customer

2. **Create Bill:**
   - Go to Billing screen
   - Add products to cart
   - Select customer
   - Set payment mode
   - Save bill

3. **Verify:**
   - Check bill appears in Bills list
   - Open bill details
   - Verify all items and totals
   - Check stock reduced for products

4. **Generate Report:**
   - Go to Reports
   - Verify bill appears in sales report
   - Check GST calculation in GST report

**Expected Result:** ✅ End-to-end flow works perfectly

---

## Troubleshooting

### Issue 1: Code Generation Fails

**Error:** `build_runner` fails or generates errors

**Solutions:**
```bash
# Clean build
flutter clean
flutter pub get

# Delete generated files manually
# Remove all *.g.dart files in lib/database/

# Regenerate
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue 2: App Won't Compile

**Error:** Missing imports or undefined classes

**Solutions:**
1. Ensure code generation completed successfully
2. Check all `*.g.dart` files exist
3. Run `flutter pub get` again
4. Check for syntax errors in your code

### Issue 3: Database Errors

**Error:** "Table doesn't exist" or similar

**Solutions:**
1. Uninstall app from device: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only` (with device connected)
2. Reinstall (database will be recreated)
3. Or manually delete app data

### Running on device and uninstall

- After deploying with `flutter run`, the app is installed on the device and **works standalone** (you can disconnect the device and use the app from the app drawer).
- To remove the app from the connected device: `adb uninstall com.billingservice.app` or `flutter run --uninstall-only`.

### Issue 4: Camera/Barcode Scanner Not Working

**Error:** Camera permission denied or scanner doesn't open

**Solutions:**
1. Check AndroidManifest.xml has camera permission
2. Grant camera permission manually in device settings
3. Test on physical device (emulators may have camera issues)

### Issue 5: Bluetooth Printer Not Found

**Error:** Can't find printer

**Solutions:**
1. Ensure printer is powered on and in pairing mode
2. Check Bluetooth is enabled on device
3. Pair printer with device first in Android settings
4. Try scanning again

### Issue 6: Google Drive Backup Fails

**Error:** Sign-in fails or backup doesn't work

**Solutions:**
1. Check internet connection
2. Verify Google account credentials
3. Check if Google Drive API is properly configured
4. Review error messages in console

---

## Performance Testing

### Test with Large Dataset

1. **Add 100+ Products**
   - Test search performance
   - Test list scrolling

2. **Create 50+ Bills**
   - Test bills list performance
   - Test date filtering speed

3. **Generate Reports**
   - Test with large date ranges
   - Check export performance

---

## Device Testing

Test on multiple devices:
- [ ] Android 7.0 (API 24) - Minimum
- [ ] Android 10 (API 29)
- [ ] Android 13+ (API 33+)
- [ ] Different screen sizes (phone, tablet)
- [ ] Different manufacturers (Samsung, Xiaomi, etc.)

---

## Common Test Scenarios

### Scenario 1: First Time User
1. Install app
2. Login with default credentials
3. Add shop details in Settings
4. Add products
5. Create first bill

### Scenario 2: Daily Operations
1. Login
2. Check dashboard for today's sales
3. Process multiple bills
4. Check low stock alerts
5. Generate end-of-day report

### Scenario 3: Backup and Restore
1. Create some data (products, bills)
2. Perform backup to Google Drive
3. Uninstall app
4. Reinstall app
5. Restore from backup (if implemented)

---

## Success Criteria

✅ All tests pass
✅ No crashes or errors
✅ Data persists correctly
✅ All features work as expected
✅ Performance is acceptable
✅ UI is responsive

---

## Next Steps After Testing

1. Fix any bugs found
2. Optimize performance if needed
3. Add missing features
4. Prepare for production build
5. Create user documentation

---

## Quick Test Commands

```bash
# Run app in debug mode
flutter run

# Run with hot reload enabled (default)
# Press 'r' to hot reload
# Press 'R' to hot restart

# Run on specific device
flutter run -d <device-id>

# Build APK for testing
flutter build apk --debug

# Check for issues
flutter analyze

# Run tests (if test files exist)
flutter test
```

---

**Happy Testing! 🚀**

If you encounter any issues not covered here, check the console logs and error messages for detailed information.
