# Database Location, Security & Data Retention

## Where is the database created on the device?

The app uses Flutter’s **path_provider** and stores the DB in the **app-private documents directory**:

- **Android:**  
  `getApplicationDocumentsDirectory()` → typically  
  **`/data/data/<package_id>/app_flutter/`**  
  So the DB file is:  
  **`/data/data/com.billingservice.app/app_flutter/billing_service.db`**

- **iOS:**  
  App’s Documents directory (sandboxed), e.g.  
  **`.../Documents/billing_service.db`**

This folder is **internal app storage**: the user and other apps cannot see or access it through normal file managers. On a non-rooted device, only your app can read/write this path.

---

## How secure is it?

- **Sandboxing:**  
  The DB lives in the app’s private directory. Other apps cannot read it. The OS enforces this.

- **No encryption at rest (current):**  
  The SQLite file is stored as plain data on disk inside the sandbox. If someone gets physical access to the device and roots it (or uses backup/ADB with sufficient privileges), they could read the file. For typical use (personal/emulator/testing), this is acceptable.

- **Making it more secure (optional):**  
  To encrypt the DB on disk you could:
  - Use **drift with `sqlcipher_flutter_libs`** (or similar) so the whole DB file is encrypted, or  
  - Use Android **EncryptedSharedPreferences** / **EncryptedFile** only for very small secrets, not the full DB.  
  Right now the app does **not** use DB-level encryption.

- **Backups:**  
  The backup service encrypts the copy before uploading to Google Drive; the file on the device in app storage is still the same (sandboxed, not encrypted).

---

## If the app or device crashes, can data be retained?

- **Yes, for committed data.**  
  The app uses **Drift** (SQLite). Data is written to **`billing_service.db`** on disk. Once a transaction is **committed**, it is persisted in that file.

- **App crash:**  
  Committed transactions remain in the DB. The next app launch opens the same file and all committed data is there. Only work that was in progress and **not** committed at the time of the crash can be lost (e.g. one incomplete invoice).

- **Device crash / power loss:**  
  SQLite is ACID-compliant and uses a write-ahead log (WAL) or rollback journal. After a crash, on next open SQLite will recover to a consistent state. You might lose the last uncommitted transaction, but the DB file itself is retained and not corrupted in normal conditions.

- **App uninstall:**  
  The OS deletes the app’s data directory. **`billing_service.db` is deleted** with it. The only way to retain data after uninstall is to **restore from a backup** (e.g. Google Drive backup in this app) before uninstalling.

- **Recommendation:**  
  Use the in-app **backup to Google Drive** (or similar) regularly so you have a copy outside the device. Then even if the device is lost, reset, or the app is uninstalled, you can restore from that backup.

---

## Summary

| Topic              | Detail                                                                 |
|--------------------|------------------------------------------------------------------------|
| **Location**       | `.../app_flutter/billing_service.db` (app-private, not user-visible)   |
| **Security**       | Sandboxed per app; no DB encryption at rest in current implementation |
| **App crash**      | Committed data is retained; uncommitted work may be lost               |
| **Device crash**   | DB file is retained; SQLite recovers to a consistent state              |
| **Uninstall**      | DB is deleted with app data; restore from backup if you need it        |
