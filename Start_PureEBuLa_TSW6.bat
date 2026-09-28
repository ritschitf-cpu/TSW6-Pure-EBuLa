@echo off
setlocal EnableExtensions
title Pure EBuLa - TSW 6 Launcher

cd /d "%~dp0"

echo.
echo ============================================
echo        Pure EBuLa - TSW 6 Launcher
echo ============================================
echo.
echo Starte Pure EBuLa Bridge...

if exist "%~dp0PureEBuLaBridge.exe" (
    start "Pure EBuLa Bridge" /D "%~dp0" "%~dp0PureEBuLaBridge.exe"
) else (
    if exist "%~dp0bridge\PureEBuLaBridge.exe" (
        start "Pure EBuLa Bridge" /D "%~dp0bridge" "%~dp0bridge\PureEBuLaBridge.exe"
    ) else (
        echo FEHLER: PureEBuLaBridge.exe wurde nicht gefunden.
        echo Lege die EXE neben diese BAT oder in den Unterordner bridge.
        pause
        exit /b 1
    )
)

timeout /t 2 /nobreak >nul

echo Starte TSW 6 mit lokaler HTTP-Schnittstelle...
echo.

set "STEAM_EXE="

for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find /i "SteamPath"') do set "STEAM_EXE=%%B\steam.exe"

if not defined STEAM_EXE (
    for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Valve\Steam" /v InstallPath 2^>nul ^| find /i "InstallPath"') do set "STEAM_EXE=%%B\steam.exe"
)

if not defined STEAM_EXE (
    echo FEHLER: Steam wurde nicht gefunden.
    echo.
    echo Du kannst TSW 6 manuell mit dem Steam-Startparameter -HTTPAPI starten.
    pause
    exit /b 1
)

if not exist "%STEAM_EXE%" (
    echo FEHLER: Steam.exe wurde nicht gefunden:
    echo %STEAM_EXE%
    pause
    exit /b 1
)

echo Steam: %STEAM_EXE%
echo TSW 6 App-ID: 3656800
echo Startparameter: -HTTPAPI
echo.
echo Hinweis: Die TSW-HTTP-API laeuft lokal auf dem PC.
echo Fuer die EBuLa-Verbindung ist kein Internet erforderlich.
echo.

start "Steam - TSW 6" "%STEAM_EXE%" -applaunch 3656800 -HTTPAPI

echo TSW 6 wurde an Steam uebergeben.
echo Pure EBuLa Bridge laeuft im Hintergrund.
echo.
echo Dieses Fenster kann geschlossen werden.
echo Die Bridge bleibt dabei aktiv.
echo.
pause
endlocal
