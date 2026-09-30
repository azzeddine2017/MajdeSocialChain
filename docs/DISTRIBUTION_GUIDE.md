# Mejde (مجد) - Multi-Platform Distribution & Packaging Guide

This guide provides comprehensive, step-by-step instructions for packaging, compiling, and distributing **Mejde (SocialChain)** across desktop and mobile platforms using official Ring ecosystem tools:

1. **`ring2exe-plus`**: Compiles the application into a self-contained, console-free (`-gui`) native desktop executable with bundled dynamic runtime libraries and embedded branding.
2. **`Inno Setup`**: Generates a professional, bilingual Windows installer wizard (`Mejde_Setup_v1.0.0_x64.exe`) with desktop shortcuts, Start Menu integration, and `mejde://` URI scheme registration.
3. **`ring2apk`**: Builds standalone Android packages (`.apk`) using `NativeActivity`, embedded Ring bytecode, native LibSQL, and pre-bundled WebView assets—bypassing heavy Gradle/Android Studio overhead.

---

## 🖥️ 1. Standalone Desktop Bundling (`ring2exe-plus`)

Desktop configurations are defined in [`ring2exe.conf`](../ring2exe.conf):
* **`-gui`**: Suppresses the Windows command console window for a clean consumer experience.
* **`-auto-libs`**: Automatically identifies and copies necessary dynamic libraries (`webview.dll`, `libsql.dll`, OpenSSL) into the output directory.
* **`-icon=public/logo.png`**: Embeds the official high-resolution application branding icon into the binary header.

### Windows Compilation

Run the automated build script from the repository root:
```cmd
scripts\build_desktop.bat
```

Or execute `ring2exe` directly:
```cmd
ring2exe app.ring -gui -auto-libs -icon=public/logo.png -output=Mejde -release
```

#### Output Structure
The compilation produces a standalone distribution folder in `release\Mejde-Windows-x64\`:
```
release/Mejde-Windows-x64/
├── Mejde.exe                 # Main compiled native executable
├── webview.dll               # WebView native runtime
├── ring_libsql.dll           # Embedded LibSQL companion database engine
├── ring_openssl.dll          # OpenSSL cryptography runtime
├── frontend/dist/index.html  # Compiled singlefile frontend bundle
├── assets/                   # Brand icons and visual assets
└── ring/                     # Bytecode and source packages
```

### Linux Compilation

```bash
chmod +x scripts/build_desktop.sh
./scripts/build_desktop.sh
```

---

## 📦 2. Professional Windows Installer (Inno Setup)

To deliver a polished distribution package for end users that installs into `Program Files`, adds Start Menu shortcuts, and registers protocol handlers:

### Installer Features
* **Bilingual UI**: Interactive Arabic and English setup wizard.
* **Architecture Verification**: Restricts installation to 64-bit Windows systems.
* **Deep Linking**: Registers the custom `mejde://` URL protocol to launch the app directly from web links.
* **Clean Uninstallation**: Removes application binaries while safely preserving user wallet seed databases.

### Compilation Steps
1. Install [Inno Setup 6+](https://jrsoftware.org/isinfo.php).
2. Open [`installer/mejde_installer.iss`](../installer/mejde_installer.iss) in **Inno Setup Compiler**.
3. Press **Compile** (`Ctrl + F9`) or run via command line:
   ```cmd
   iscc installer\mejde_installer.iss
   ```
4. The signed/ready installer will be output to:
   ```
   release\Mejde_Setup_v1.0.0_x64.exe
   ```

---

## 📱 3. Android APK Build Pipeline (`ring2apk`)

Mejde utilizes `ring2apk` to generate lean, ultra-fast native Android packages without requiring Android Studio. All mobile configurations are declared in [`ring2apk.ring`](../ring2apk.ring).

### Architecture Highlights
* **NativeActivity**: The entire Ring runtime runs inside a native C/C++ activity for maximum speed and minimal memory footprint.
* **Embedded LibSQL Engine**: Bundled native `.so` binaries for `arm64-v8a`, `armeabi-v7a`, and `x86_64` guarantee zero network latency for local database queries.
* **Singlefile WebView Bundle**: The Svelte frontend is compiled to a single, asset-loaded `index.html` file accessed via `file:///android_asset/`.
* **System File & Camera Picker**: Native file chooser bridge (`onShowFileChooser`) integrated into `MainActivity.java` enables direct camera capture and gallery photo selection.

---

### Step 1: Automatic Android Environment Setup
If your system lacks Android SDK/NDK tools, run the automated environment bootstrapper:
```cmd
android\setup_android_env.bat
```
This utility automatically:
* Detects or downloads the Android Command Line Tools, SDK 34, NDK (r25+), CMake, and OpenJDK 17.
* Configures persistent environment variables (`ANDROID_HOME`, `ANDROID_NDK_ROOT`, `JAVA_HOME`).
* Symlinks SDK platforms (`platforms\android-34`) for seamless build compatibility.

---

### Step 2: Build the APK
From the repository root, run:

```cmd
:: On Windows
android\build_apk.bat

# On Linux / macOS
chmod +x android/build_apk.sh
./android/build_apk.sh
```

The script performs the complete build pipeline:
1. Rebuilds the frontend bundle via `npm run build` in `frontend/`.
2. Synchronizes source packages, brand logos, and assets into `android/assets/`.
3. Invokes `ring2apk build` to assemble the native APK.

#### Output APK
The generated package will be located at:
```
build/Mejde-debug.apk     (Debug testing build)
build/Mejde-release.apk   (Production release build)
```

---

### Step 3: Installing & Debugging on Device

#### Install via ADB:
```cmd
adb install -r build/Mejde-debug.apk
```

#### Monitor Live Logs:
Filter logcat output specifically for Mejde and Ring VM messages:
```cmd
adb logcat -s RingOutput:D
```

---

## 🛠️ 4. Troubleshooting & Best Practices

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| **`Error (R35) : Can't create/open the file`** | Attempting to write files to relative paths in Android's restricted sandbox root. | Use the companion database table `media_blobs` via `MediaStorageService.setDB(oDatabase)`. Media blobs are stored in SQLite and indexed by SHA-256 CID. |
| **`Wrong password / فشل فك التشفير`** | Multi-account resolution ambiguity when querying local users after logout. | `js_unlockWallet` checks `last_user_id` from `sync_state` and iterates over valid encrypted accounts (`ORDER BY rowid DESC`). |
| **Camera / Gallery Picker Not Opening** | Missing `WebChromeClient.onShowFileChooser` in custom WebView activities. | Ensured `onShowFileChooser` and `onActivityResult` are properly implemented in `MainActivity.java` with `READ_MEDIA_IMAGES` and `CAMERA` permissions. |
| **Missing Dynamic Library Error (`R38`)** | Runtime dependencies (`libring_webview.so`, `libring_openssl.so`) missing from APK `lib/` directory. | Re-run `android\build_apk.bat` which synchronizes native `.so` files across all target ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`). |
