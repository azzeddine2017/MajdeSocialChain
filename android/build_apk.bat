@echo off
@chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================================================
echo        MEJDE NETWORK - ANDROID APK BUILDER (Powered by ring2apk)
echo ========================================================================

:: Refresh environment variables from Windows Registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_HOME 2^>nul') do set "ANDROID_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_SDK_ROOT 2^>nul') do set "ANDROID_SDK_ROOT=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_NDK_ROOT 2^>nul') do set "ANDROID_NDK_ROOT=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v NDK_HOME 2^>nul') do set "NDK_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v JAVA_HOME 2^>nul') do set "JAVA_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v CMAKE_HOME 2^>nul') do set "CMAKE_HOME=%%b"

if not defined ANDROID_HOME (
    if exist "%USERPROFILE%\Android" (
        set "ANDROID_HOME=%USERPROFILE%\Android"
        set "ANDROID_SDK_ROOT=%USERPROFILE%\Android"
    )
)

if defined ANDROID_HOME (
    set "PATH=%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;!PATH!"
)
if defined JAVA_HOME (
    set "PATH=%JAVA_HOME%\bin;!PATH!"
)
if defined CMAKE_HOME (
    set "PATH=%CMAKE_HOME%;!PATH!"
)

:: Ensure platforms\android-34 is mapped to the installed platform
if defined ANDROID_HOME (
    if not exist "%ANDROID_HOME%\platforms\android-34" (
        for /d %%d in ("%ANDROID_HOME%\platforms\android-*") do (
            if not exist "%ANDROID_HOME%\platforms\android-34" (
                echo [*] Linking platform %%~nxd as android-34 for compatibility...
                mklink /j "%ANDROID_HOME%\platforms\android-34" "%%d" >nul 2>nul
            )
        )
    )
)

set PROJECT_ROOT=%~dp0..
cd /d "%PROJECT_ROOT%"

echo.
echo [1/3] Building Frontend bundle and synchronizing brand logo...
cd /d "%PROJECT_ROOT%\frontend"
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Frontend build failed!
    exit /b 1
)
cd /d "%PROJECT_ROOT%"

echo.
echo [2/3] Preparing Android packaging structure (ring/ and assets/)...
if not exist "%PROJECT_ROOT%\ring" mkdir "%PROJECT_ROOT%\ring"
copy /y "%PROJECT_ROOT%\app.ring" "%PROJECT_ROOT%\ring\app.ring" >nul
if exist "%PROJECT_ROOT%\ring\node.ring" del /f /q "%PROJECT_ROOT%\ring\node.ring" >nul
if exist "%PROJECT_ROOT%\main.ring" copy /y "%PROJECT_ROOT%\main.ring" "%PROJECT_ROOT%\ring\main.ring" >nul

xcopy /y /e /i /q "%PROJECT_ROOT%\blockchain" "%PROJECT_ROOT%\ring\blockchain" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\contracts" "%PROJECT_ROOT%\ring\contracts" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\core" "%PROJECT_ROOT%\ring\core" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\models" "%PROJECT_ROOT%\ring\models" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\p2p" "%PROJECT_ROOT%\ring\p2p" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\services" "%PROJECT_ROOT%\ring\services" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\utils" "%PROJECT_ROOT%\ring\utils" >nul 2>nul

if not exist "%PROJECT_ROOT%\android\assets" mkdir "%PROJECT_ROOT%\android\assets"
if not exist "%PROJECT_ROOT%\android\assets\frontend\dist" mkdir "%PROJECT_ROOT%\android\assets\frontend\dist"
copy /y "%PROJECT_ROOT%\frontend\dist\index.html" "%PROJECT_ROOT%\android\assets\frontend\dist\index.html" >nul

if not exist "%PROJECT_ROOT%\assets" mkdir "%PROJECT_ROOT%\assets"
if not exist "%PROJECT_ROOT%\assets\frontend\dist" mkdir "%PROJECT_ROOT%\assets\frontend\dist"
copy /y "%PROJECT_ROOT%\frontend\dist\index.html" "%PROJECT_ROOT%\assets\frontend\dist\index.html" >nul
if exist "%PROJECT_ROOT%\public\logo.png" (
    copy /y "%PROJECT_ROOT%\public\logo.png" "%PROJECT_ROOT%\android\assets\icon.png" >nul
    copy /y "%PROJECT_ROOT%\public\logo.png" "%PROJECT_ROOT%\assets\icon.png" >nul
)

:: Populate Android WebView Ring loader bindings to ring\ and ring\src
if not exist "%PROJECT_ROOT%\ring\src" mkdir "%PROJECT_ROOT%\ring\src"
if exist "%PROJECT_ROOT%\src\cpp\thirdparty\webview\examples\android\ring\src" (
    xcopy /y /e /i /q "%PROJECT_ROOT%\src\cpp\thirdparty\webview\examples\android\ring\src" "%PROJECT_ROOT%\ring\src" >nul 2>nul
)
if exist "%PROJECT_ROOT%\src\cpp\thirdparty\webview\examples\android\ring\webview.ring" (
    copy /y "%PROJECT_ROOT%\src\cpp\thirdparty\webview\examples\android\ring\webview.ring" "%PROJECT_ROOT%\ring\webview.ring" >nul 2>nul
)
if exist "%PROJECT_ROOT%\libsql.ring" (
    copy /y "%PROJECT_ROOT%\libsql.ring" "%PROJECT_ROOT%\ring\libsql.ring" >nul 2>nul
)
if exist "%PROJECT_ROOT%\openssllib.ring" (
    copy /y "%PROJECT_ROOT%\openssllib.ring" "%PROJECT_ROOT%\ring\openssllib.ring" >nul 2>nul
)

:: Ensure native engine (both C/C++ and Java) is present
if not exist "%PROJECT_ROOT%\src\cpp\CMakeLists.txt" (
    if exist "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\src" (
        echo [*] Setting up native WebView engine [C/C++ + Java] from ring2apk template...
        xcopy /y /e /i /q "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\src" "%PROJECT_ROOT%\src" >nul 2>nul
    )
)

if not exist "%PROJECT_ROOT%\AndroidManifest.xml" (
    if exist "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\AndroidManifest.xml" (
        echo [*] Using WebView AndroidManifest from ring2apk...
        copy /y "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\AndroidManifest.xml" "%PROJECT_ROOT%\AndroidManifest.xml" >nul 2>nul
    )
)

if exist "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\res" (
    xcopy /y /e /i /q "C:\ring\tools\ringpm\packages\ring2apk\examples\webview\res" "%PROJECT_ROOT%\res" >nul 2>nul
)

:: Vendor Ring VM C sources to src\cpp\ring
if not exist "%PROJECT_ROOT%\src\cpp\ring\src" (
    if exist "C:\ring\language\src" (
        echo [*] Vendoring Ring VM C sources to src\cpp\ring...
        if not exist "%PROJECT_ROOT%\src\cpp\ring\src" mkdir "%PROJECT_ROOT%\src\cpp\ring\src"
        if not exist "%PROJECT_ROOT%\src\cpp\ring\include" mkdir "%PROJECT_ROOT%\src\cpp\ring\include"
        xcopy /y /e /i /q "C:\ring\language\src" "%PROJECT_ROOT%\src\cpp\ring\src" >nul 2>nul
        xcopy /y /e /i /q "C:\ring\language\include" "%PROJECT_ROOT%\src\cpp\ring\include" >nul 2>nul
    )
)

:: Remove Windows/CLI specific entrypoints from Ring VM native build
if exist "%PROJECT_ROOT%\src\cpp\ring\src\ringw.c" del /f /q "%PROJECT_ROOT%\src\cpp\ring\src\ringw.c" >nul 2>nul
if exist "%PROJECT_ROOT%\src\cpp\ring\src\ring.c" del /f /q "%PROJECT_ROOT%\src\cpp\ring\src\ring.c" >nul 2>nul

:: Clean stale AndroidManifest in build to force fresh generation
if exist "%PROJECT_ROOT%\build\AndroidManifest.xml" del /f /q "%PROJECT_ROOT%\build\AndroidManifest.xml" >nul 2>nul

echo [*] Android ring, native engine, and assets packages prepared.


echo.
echo [3/3] Compiling Android APK with ring2apk...
where ring2apk >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    call ring2apk build --rebuild
) else (
    where ring >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        ring ring2apk.ring build --rebuild
    ) else (
        echo [ERROR] ring2apk command not found in PATH!
        exit /b 1
    )
)

echo.
echo ========================================================================
echo [DONE] Android compilation finished.
echo ========================================================================
