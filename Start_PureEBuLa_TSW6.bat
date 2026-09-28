@echo off
setlocal EnableExtensions
title Pure EBuLa - TSW 6 Direct Launcher
cd /d "%~dp0"

echo.
echo ============================================
echo      Pure EBuLa - TSW 6 DIRECT LAUNCHER
echo ============================================
echo.

echo [1/3] Starte Pure EBuLa Bridge...
if exist "%~dp0PureEBuLaBridge.exe" (
    start "Pure EBuLa Bridge" /D "%~dp0" "%~dp0PureEBuLaBridge.exe"
) else if exist "%~dp0bridge\PureEBuLaBridge.exe" (
    start "Pure EBuLa Bridge" /D "%~dp0bridge" "%~dp0bridge\PureEBuLaBridge.exe"
) else (
    echo FEHLER: PureEBuLaBridge.exe wurde nicht gefunden.
    pause
    exit /b 1
)

timeout /t 2 /nobreak >nul

echo [2/3] Suche TSW 6 direkt auf dem PC...
set "TSW_EXE="

if exist "C:\Program Files (x86)\Steam\steamapps\common\Train Sim World 6\WindowsNoEditor\TS2Prototype\Binaries\Win64\TrainSimWorld.exe" set "TSW_EXE=C:\Program Files (x86)\Steam\steamapps\common\Train Sim World 6\WindowsNoEditor\TS2Prototype\Binaries\Win64\TrainSimWorld.exe"
if not defined TSW_EXE if exist "C:\Program Files (x86)\Steam\steamapps\common\Train Sim World 6\WindowsNoEditor\TrainSimWorld.exe" set "TSW_EXE=C:\Program Files (x86)\Steam\steamapps\common\Train Sim World 6\WindowsNoEditor\TrainSimWorld.exe"
if not defined TSW_EXE if exist "D:\SteamLibrary\steamapps\common\Train Sim World 6\WindowsNoEditor\TS2Prototype\Binaries\Win64\TrainSimWorld.exe" set "TSW_EXE=D:\SteamLibrary\steamapps\common\Train Sim World 6\WindowsNoEditor\TS2Prototype\Binaries\Win64\TrainSimWorld.exe"
if not defined TSW_EXE if exist "D:\SteamLibrary\steamapps\common\Train Sim World 6\WindowsNoEditor\TrainSimWorld.exe" set "TSW_EXE=D:\SteamLibrary\steamapps\common\Train Sim World 6\WindowsNoEditor\TrainSimWorld.exe"

if not defined TSW_EXE (
    echo.
    echo TSW 6 wurde an keinem Standardpfad gefunden.
    echo.
    set /p "TSW_EXE=Bitte den kompletten Pfad zu TrainSimWorld.exe eingeben: "
)

if not exist "%TSW_EXE%" (
    echo.
    echo FEHLER: Diese TrainSimWorld.exe wurde nicht gefunden:
    echo %TSW_EXE%
    pause
    exit /b 1
)

for %%F in ("%TSW_EXE%") do set "TSW_DIR=%%~dpF"

echo Gefunden:
echo %TSW_EXE%
echo.

echo [3/3] Aktiviere direkten TSW6-Start und HTTPAPI...
if not exist "%TSW_DIR%steam_appid.txt" (
    >"%TSW_DIR%steam_appid.txt" echo 3656800
    echo steam_appid.txt wurde angelegt.
) else (
    echo steam_appid.txt ist bereits vorhanden.
)

echo.
echo Starte TSW 6 direkt - ohne Steam-Launcher...
echo Startparameter: -HTTPAPI
echo.
echo Die EBuLa-Kommunikation bleibt lokal.
echo Kein Internet fuer Bridge <-> TSW <-> APK erforderlich.
echo.

start "Train Sim World 6" /D "%TSW_DIR%" "%TSW_EXE%" -HTTPAPI

echo TSW 6 wurde direkt gestartet.
echo Pure EBuLa Bridge laeuft im Hintergrund.
echo.
echo Dieses Fenster kann jetzt geschlossen werden.
pause
endlocal
