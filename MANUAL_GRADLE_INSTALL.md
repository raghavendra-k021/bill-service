# Manual Gradle Install (Bypass SSL / Certificate Errors)

**Project folder:** `bill-service`

If `flutter run` or `flutter build apk` fails with an **SSL certificate error** when downloading Gradle (e.g. `PKIX path building failed`), download Gradle in a browser or with `curl` and place the zip where the wrapper expects it. The wrapper then uses the local file instead of HTTPS.

This project uses **Gradle 8.14** (`gradle-8.14-all.zip`). Older zips (`8.9`, `8.11.1`) will not satisfy Flutter 3.47.

---

## Step 1: Create the target folder

Run this **once** from the project folder (it may fail with SSL — that is expected). Gradle creates the dist folder and hash directory:

```bash
cd bill-service
flutter build apk --release
```

**Windows (File Explorer / PowerShell):**

```
%USERPROFILE%\.gradle\wrapper\dists\gradle-8.14-all
```

Example: `C:\Users\raghak\.gradle\wrapper\dists\gradle-8.14-all`

**WSL / Linux:**

```
~/.gradle/wrapper/dists/gradle-8.14-all
```

Inside it there will be **one folder** with a compact hash name. For this wrapper URL the hash is:

```
c2qonpi39x1mddn7hk5gh9iqj
```

If that folder is missing, run a Flutter Android build once so it is created, then ignore the SSL error.

---

## Step 2: Download Gradle 8.14

**Browser:** open

```
https://services.gradle.org/distributions/gradle-8.14-all.zip
```

Save it as **`gradle-8.14-all.zip`** (do not rename).

**WSL / Linux (`curl`):**

```bash
DEST="$HOME/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj"
mkdir -p "$DEST"
curl -L --fail -o "$DEST/gradle-8.14-all.zip" \
  "https://services.gradle.org/distributions/gradle-8.14-all.zip"
```

---

## Step 3: Place the zip (if you used a browser)

1. Open the `gradle-8.14-all` dist folder (Windows or WSL path above).
2. Open the hash subfolder (`c2qonpi39x1mddn7hk5gh9iqj`, or the most recently modified hash folder).
3. Copy **`gradle-8.14-all.zip`** into that folder. **Do not unzip it.**

Final path examples:

```
C:\Users\raghak\.gradle\wrapper\dists\gradle-8.14-all\c2qonpi39x1mddn7hk5gh9iqj\gradle-8.14-all.zip
```

```
~/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj/gradle-8.14-all.zip
```

---

## Step 4: Build again

```bash
cd bill-service
flutter build apk --release
```

Gradle extracts the local zip and should not download the distribution over HTTPS.

---

## Quick reference

| Item | Value |
|------|--------|
| Wrapper URL | https://services.gradle.org/distributions/gradle-8.14-all.zip |
| File name | `gradle-8.14-all.zip` (keep this name) |
| Hash folder | `c2qonpi39x1mddn7hk5gh9iqj` |
| Windows | `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.14-all\<hash>\` |
| WSL / Linux | `~/.gradle/wrapper/dists/gradle-8.14-all/<hash>/` |

---

## If you have multiple hash folders

Use the **most recently modified** one from the last Flutter/Gradle run. Put `gradle-8.14-all.zip` in that folder.

Do **not** use `install_gradle_8.9.bat` — it installs Gradle 8.9, which Flutter 3.47 rejects (minimum is **8.14.0**).
