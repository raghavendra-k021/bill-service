# Manual Gradle Install (Bypass SSL / Certificate Errors)

**Project folder:** `bill-service`

If `flutter run` fails with **SSL certificate error** when downloading Gradle (e.g. "PKIX path building failed"), you can download Gradle manually and place it so the build uses it without going over HTTPS.

---

## Step 1: Create the target folder (so you know where to put the zip)

Run this **once** from the project folder (it will fail with SSL – that’s expected):

```powershell
cd C:\Users\raghak\workspace_raghak\bill-service
flutter run
```

When it fails, Gradle will have created a folder under your user profile. You need that path.

**Or** open this folder in File Explorer:

```
%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all
```

- Full path example: `C:\Users\raghak\.gradle\wrapper\dists\gradle-8.11.1-all`
- Inside it there will be **one folder** with a long name (a hash, e.g. `a1b2c3d4e5f6...`).  
  If you already ran `flutter run` and it failed, that hash folder was created.  
  If the folder `gradle-8.11.1-all` is empty or missing, run `flutter run` once so it gets created (then ignore the SSL error).

---

## Step 2: Download Gradle manually

1. In your **browser** (Chrome, Edge, etc.), open:
   ```
   https://services.gradle.org/distributions/gradle-8.11.1-all.zip
   ```
2. Download the file (e.g. “Save as”).
3. Remember where you saved it (e.g. `Downloads\gradle-8.11.1-all.zip`).  
   The file **must** be named **`gradle-8.11.1-all.zip`**.

---

## Step 3: Place the zip in the Gradle wrapper folder

1. Go to:
   ```
   %USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all
   ```
   (e.g. `C:\Users\raghak\.gradle\wrapper\dists\gradle-8.11.1-all`)

2. Open the **only subfolder** inside it (the one with the long hash name).

3. **Copy** your downloaded **`gradle-8.11.1-all.zip`** into that hash folder.  
   Do **not** rename it. Do **not** unzip it.  
   Final path should look like:
   ```
   C:\Users\raghak\.gradle\wrapper\dists\gradle-8.11.1-all\<hash>\gradle-8.11.1-all.zip
   ```

---

## Step 4: Run the app again

From the project folder:

```powershell
cd C:\Users\raghak\workspace_raghak\bill-service
flutter run
```

Gradle will use the local zip and will not try to download it over HTTPS, so the SSL error should be gone.

---

## Quick reference

| Item | Value |
|------|--------|
| Download URL | https://services.gradle.org/distributions/gradle-8.11.1-all.zip |
| File name | `gradle-8.11.1-all.zip` (keep this name) |
| Place in | `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all\<hash>\` |
| Full path example | `C:\Users\raghak\.gradle\wrapper\dists\gradle-8.11.1-all\<hash>\gradle-8.11.1-all.zip` |

---

## If the hash folder doesn’t exist yet

1. Run `flutter run` once and wait for the SSL error (Gradle will create the folder).
2. Then open `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all\` and you should see one folder (the hash). Put the zip inside that folder.
3. Run `flutter run` again.

## If you have multiple hash folders

Use the **most recently modified** one (that’s from the last run). Put `gradle-8.11.1-all.zip` in that folder.
