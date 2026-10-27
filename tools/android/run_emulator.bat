@echo off
rem Builds the debug APK, starts the virtual phone if needed, installs and runs the game.
rem Double-click it, or run it from the project folder. Paths: edit the three lines below if they change.
set GODOT=C:\Users\MyPC\Desktop\Godot_v4.5.1-stable_win64_console.exe
set SDK=G:\AndroidSDK
set AVD=KingdomTiles_Phone

cd /d "%~dp0\..\.."
if not exist build mkdir build
echo [1/4] Exporting build\KingdomTiles.apk ...
"%GODOT%" --headless --path . --export-debug "kingdomtiles" build\KingdomTiles.apk
if errorlevel 1 (
  echo Export failed.
  pause
  exit /b 1
)

"%SDK%\platform-tools\adb.exe" get-state >nul 2>&1
if errorlevel 1 (
  echo [2/4] Starting the virtual phone %AVD% ...
  start "" "%SDK%\emulator\emulator.exe" -avd %AVD% -no-snapshot-save -no-boot-anim
) else (
  echo [2/4] The virtual phone is already running.
)
"%SDK%\platform-tools\adb.exe" wait-for-device
:wait_boot
for /f "delims=" %%b in ('"%SDK%\platform-tools\adb.exe" shell getprop sys.boot_completed') do set BOOTED=%%b
if not "%BOOTED%"=="1" (
  timeout /t 2 /nobreak >nul
  goto wait_boot
)

echo [3/4] Installing ...
"%SDK%\platform-tools\adb.exe" install -r build\KingdomTiles.apk
echo [4/4] Starting the game ...
"%SDK%\platform-tools\adb.exe" shell monkey -p com.koyomikotori.kingdomtiles -c android.intent.category.LAUNCHER 1 >nul
echo Done.
