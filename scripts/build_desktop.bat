@echo off
@chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================================================
echo        MEJDE NETWORK - DESKTOP BUILDER (Powered by ring2exe-plus)
echo ========================================================================

set PROJECT_ROOT=%~dp0..
cd /d "%PROJECT_ROOT%"

set DIST_DIR=%PROJECT_ROOT%\release\Mejde-Windows-x64
if not exist "%PROJECT_ROOT%\release" mkdir "%PROJECT_ROOT%\release"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

echo.
echo [1/4] Building Frontend bundle and synchronizing brand logo (PNG + ICO)...
cd /d "%PROJECT_ROOT%\frontend"
call npm run build
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Frontend build failed!
    exit /b 1
)
cd /d "%PROJECT_ROOT%"

echo.
echo [2/4] Locating Ring installation and compiling standalone executable...
set RING_BIN=
for /f "delims=" %%i in ('where ring.exe 2^>nul') do (
    if not defined RING_BIN set RING_BIN=%%~dpi
)
if not defined RING_BIN (
    if exist "C:\ring\bin\ring.exe" set RING_BIN=C:\ring\bin\
)

if not defined RING_BIN (
    echo [ERROR] Ring runtime not found!
    exit /b 1
)

set RING2EXE_CMD=
where ring2exe >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set RING2EXE_CMD=ring2exe
) else (
    set RING2EXE_CMD=ring ring2exe.ring
)

echo [*] Compiling with ring2exe-plus:
echo     %RING2EXE_CMD% app.ring -gui -auto-libs -icon=public\logo.ico -output=Mejde -release
call %RING2EXE_CMD% app.ring -gui -auto-libs -icon=public\logo.ico -output=Mejde -release

if exist "Mejde.exe" (
    move /y "Mejde.exe" "%DIST_DIR%\" >nul
)
if exist "ring.ringo" move /y "ring.ringo" "%DIST_DIR%\" >nul
if exist "app.ringo" move /y "app.ringo" "%DIST_DIR%\" >nul
if exist "app.rc" del /f /q "app.rc" >nul 2>nul
if exist "app.res" del /f /q "app.res" >nul 2>nul
if exist "%DIST_DIR%\app.rc" del /f /q "%DIST_DIR%\app.rc" >nul 2>nul
if exist "libsql.ring" copy /y "libsql.ring" "%DIST_DIR%\" >nul
if not exist "%DIST_DIR%\logs" mkdir "%DIST_DIR%\logs"
if not exist "%DIST_DIR%\storage" mkdir "%DIST_DIR%\storage"
if not exist "%DIST_DIR%\storage\blobs" mkdir "%DIST_DIR%\storage\blobs"

echo.
echo [3/4] Packaging Ring runtime libraries and dependencies...
:: Copy ONLY the required Ring runtime DLLs (Whitelist: ring, webview, libsql, sqlite, libcurl, openssl, sockets)
copy /y "%RING_BIN%ring.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*webview*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*libsql*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*sqlite*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*libcurl*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*ssl*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*crypto*.dll" "%DIST_DIR%\" >nul 2>nul
copy /y "%RING_BIN%*socket*.dll" "%DIST_DIR%\" >nul 2>nul

:: Copy application source code and contracts
copy /y "%PROJECT_ROOT%\app.ring" "%DIST_DIR%\" >nul
copy /y "%PROJECT_ROOT%\libsql.ring" "%DIST_DIR%\" >nul
copy /y "%PROJECT_ROOT%\openssllib.ring" "%DIST_DIR%\" >nul
copy /y "%PROJECT_ROOT%\node.ring" "%DIST_DIR%\" >nul
copy /y "%PROJECT_ROOT%\cli.ring" "%DIST_DIR%\" >nul
copy /y "%PROJECT_ROOT%\README.md" "%DIST_DIR%\" >nul

xcopy /y /e /i /q "%PROJECT_ROOT%\blockchain" "%DIST_DIR%\blockchain" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\contracts" "%DIST_DIR%\contracts" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\core" "%DIST_DIR%\core" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\models" "%DIST_DIR%\models" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\p2p" "%DIST_DIR%\p2p" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\services" "%DIST_DIR%\services" >nul 2>nul
xcopy /y /e /i /q "%PROJECT_ROOT%\utils" "%DIST_DIR%\utils" >nul 2>nul

:: Copy public assets and compiled frontend
if exist "%PROJECT_ROOT%\public" (
    xcopy /y /e /i /q "%PROJECT_ROOT%\public" "%DIST_DIR%\public" >nul 2>nul
)
if not exist "%DIST_DIR%\frontend\dist" mkdir "%DIST_DIR%\frontend\dist"
copy /y "%PROJECT_ROOT%\frontend\dist\index.html" "%DIST_DIR%\frontend\dist\" >nul

echo.
echo [4/4] Creating Brand Shortcuts and Launchers...
:: 1. Create one-click batch launcher
(
echo @echo off
echo cd /d "%%~dp0"
echo start "" "Mejde.exe"
) > "%DIST_DIR%\Launch_Mejde.bat"

:: 2. Create branded Windows shortcut (.lnk) with official Mejde logo
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut('%DIST_DIR%\Mejde.lnk'); $sc.TargetPath = '%DIST_DIR%\Mejde.exe'; $sc.Arguments = ''; $sc.WorkingDirectory = '%DIST_DIR%'; $sc.IconLocation = '%DIST_DIR%\public\logo.ico,0'; $sc.Save()" >nul 2>nul


echo.
echo ========================================================================
echo [SUCCESS] Mejde Desktop Standalone Application built successfully!
echo.
echo Output Directory:
echo   %DIST_DIR%
echo.
echo You can run the application directly via:
echo   - Mejde.lnk (Branded Desktop Shortcut with Official Logo)
echo   - Launch_Mejde.bat
echo   - Mejde.exe
echo ========================================================================
