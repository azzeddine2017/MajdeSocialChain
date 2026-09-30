@echo off
setlocal enabledelayedexpansion

echo ========================================================================
echo        MEJDE NETWORK - ANDROID ENVIRONMENT SETUP [ring2apk]
echo        Automated Android SDK, NDK, CMake and JDK Toolchain Setup
echo ========================================================================

:: 1. Refresh environment variables from Windows Registry (HKCU\Environment)
:: This ensures variables set by setx in previous runs are active immediately!
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_HOME 2^>nul') do set "ANDROID_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_SDK_ROOT 2^>nul') do set "ANDROID_SDK_ROOT=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANDROID_NDK_ROOT 2^>nul') do set "ANDROID_NDK_ROOT=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v NDK_HOME 2^>nul') do set "NDK_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v JAVA_HOME 2^>nul') do set "JAVA_HOME=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v CMAKE_HOME 2^>nul') do set "CMAKE_HOME=%%b"

:: Fallback to default user Android directory if not defined
if not defined ANDROID_HOME (
    if exist "%USERPROFILE%\Android" (
        set "ANDROID_HOME=%USERPROFILE%\Android"
        set "ANDROID_SDK_ROOT=%USERPROFILE%\Android"
    )
)

:: Update PATH in current session
if defined ANDROID_HOME (
    set "PATH=%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;!PATH!"
)
if defined JAVA_HOME (
    set "PATH=%JAVA_HOME%\bin;!PATH!"
)
if defined CMAKE_HOME (
    set "PATH=%CMAKE_HOME%;!PATH!"
)

set CURRENT_DIR=%~dp0
set SETUP_DIR=
set SETUP_FILE=

if exist "C:\ring\tools\ringpm\packages\ring2apk\tools\setup-env.ring" (
    set SETUP_DIR=C:\ring\tools\ringpm\packages\ring2apk\tools
    set SETUP_FILE=setup-env.ring
    goto :run_setup
)

for /r "C:\ring" %%f in (setup-env.ring) do (
    if exist "%%f" (
        set SETUP_DIR=%%~dpf
        set SETUP_FILE=%%~nxf
        goto :run_setup
    )
)

:run_setup
if not "!SETUP_DIR!"=="" (
    echo [*] Active Environment:
    echo     ANDROID_HOME = %ANDROID_HOME%
    echo     JAVA_HOME    = %JAVA_HOME%
    echo     NDK_HOME     = %NDK_HOME%
    echo     CMAKE_HOME   = %CMAKE_HOME%
    echo.
    echo [*] Found setup tool at: !SETUP_DIR!!SETUP_FILE!
    echo [*] Launching interactive Android toolchain installer...
    echo.
    cd /d "!SETUP_DIR!"
    ring "!SETUP_FILE!"
    cd /d "!CURRENT_DIR!"
) else (
    echo [ERROR] setup-env.ring not found!
    echo Please make sure ring2apk is installed:
    echo ringpm install ring2apk from ysdragon
)

echo.
pause
