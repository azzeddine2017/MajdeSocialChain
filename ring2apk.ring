/*
    Mejde Network - Android Build Configuration for ring2apk
    Compiles Ring bytecode, LibSQL binary, and Svelte WebView into a standalone APK.
*/

Ring2ApkConfig = [
    # App identity
    :name        = "Mejde",
    :label       = "Mejde",
    :packageId   = "io.github.ysdragon.webview",
    :versionCode = 1,
    :versionName = "1.0.0",

    # Android SDK versions (minSdk 21 supports Android 5.0 through 14+, fully compatible with Android 10)
    :minSdk      = 21,
    :targetSdk   = 34,
    :compileSdk  = 34,

    # Target architectures (arm64-v8a covers modern phones, armeabi-v7a for 32-bit devices, x86_64 for emulators)
    :targets     = ["arm64-v8a", "armeabi-v7a", "x86_64"],

    # Directories
    :srcDir      = "src",
    :resDir      = "res",
    :assetsDir   = "assets",
    :outputDir   = "build",

    # Entry point Ring file & source directory
    :ringSrcDir  = "ring",
    :entryPoint  = "main.ring",

    # App display settings
    :theme       = "@style/AppTheme",
    :orientation = "unspecified",

    # Application permissions
    :permissions = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_NETWORK_STATE",
        "android.permission.ACCESS_WIFI_STATE",
        "android.permission.WAKE_LOCK",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_IMAGES"
    ]
]

