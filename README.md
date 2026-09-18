# ARMSS Gateway Mobile (Android)

ARMSS Gateway Mobile provides unified portal access, financial ledger review, device identity verification, and in-app automated self-updating for Android devices.

---

## 1. Prerequisites

Before building the mobile application, ensure your development workstation has:
- **Flutter SDK** (v3.13.1 or higher)
- **Android SDK & Build Tools** (API 34/35)
- **Java Development Kit (JDK)**: OpenJDK 17 or JDK 17 (recommended: Android Studio bundled JDK)
- Android device or emulator with Developer Options and USB Debugging enabled

---

## 2. Step-by-Step Release APK Build Guide

### Step 1: Fetch Dependencies & Run Tests
Open a terminal in the `armss_gateway_mobile` directory:
```powershell
flutter pub get
flutter test
```

### Step 2: Build the Release APK
Run the release build command:
```powershell
flutter build apk --release
```

> **Tip for 3x Faster Builds (Optional)**:
> If building specifically for modern smartphones and you want a much faster compilation time:
> ```powershell
> flutter build apk --release --split-per-abi --no-tree-shake-icons
> ```

### Step 3: Locate the Compiled APK
Once completed, the release binary is located at:
```
build\app\outputs\flutter-apk\app-release.apk
```

---

## 3. Generating the SHA-256 Checksum

Every mobile release binary must have its SHA-256 checksum calculated before configuring the backend update server. This ensures that downloads cannot be corrupted or tampered with over mobile connections.

Run this PowerShell command inside `armss_gateway_mobile`:
```powershell
Get-FileHash build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

**Example Output:**
```
Algorithm       Hash                                                             Path
---------       ----                                                             ----
SHA256          0B5172885E4E1C5E40175D65EDF2D67ABFA74DF0336B7A450DDBBA619AACE0EE   ...\app-release.apk
```

Copy the 64-character hash string.

---

## 4. Backend In-App Auto-Update Configuration

To enable mobile devices to automatically detect and download this new release:

1. Copy the compiled `app-release.apk` to your server (e.g. `/opt/armss/ARMSS_Gateway.apk`).
2. Open `.env` in `armss_gateway_backend` and update the mobile update parameters:

```env
# Mobile Android auto-update metadata
MOBILE_UPDATE_VERSION=1.1.2
MOBILE_UPDATE_URL=https://armssgateway.arminfo.in/api/v1/app/mobile-download
MOBILE_UPDATE_SHA256=<PASTE_THE_SHA256_HASH_HERE>
MOBILE_UPDATE_FILE=/opt/armss/ARMSS_Gateway.apk
```

3. Restart the backend service:
```bash
sudo systemctl restart armss-gateway-backend
```

---

## 5. How In-App Auto-Update Works on Mobile

1. **Automatic Check**: On app launch (and inside the **User Profile → App Version & Updates** screen), the app queries `GET /api/v1/app/mobile-update`.
2. **Version Comparison**: If the server version is higher than the installed version (`package_info_plus`), an **Update Available** dialog pops up.
3. **Download with Progress**: When the user taps "Update Now", the APK is streamed with a live progress indicator (`%` and `MB / Total MB`).
4. **Integrity Validation**: The app hashes the downloaded file. If the SHA-256 hash does not match the server hash, the download is immediately rejected for security.
5. **Native Installation**: The app uses Android's secure `FileProvider` and native `MethodChannel` (`com.armss.armss_gateway_mobile/app_installer`) to trigger Android's Package Installer in-place without uninstalling the existing app.

---

## 6. Device Identity & Security

- Devices register their real hardware model (e.g., `Samsung SM-S911B`, `Google Pixel 7`) via `device_info_plus`.
- Tokens are automatically generated and linked upon successful user login.
- If a device token is revoked by an administrator, the app displays a locked banner with a "Request Admin Activation" workflow.
