@echo off
chcp 65001 >nul
echo ==========================================================
echo   YAZ305 Mobil Yazilim Gelistirme - Proje 11
echo   Google Pixel 7 (Android 14) Emulatoru Aciliyor...
echo ==========================================================
set JAVA_HOME=C:\src\jdk
set ANDROID_HOME=C:\src\android-sdk
set ANDROID_SDK_ROOT=C:\src\android-sdk
set PATH=C:\src\jdk\bin;C:\src\android-sdk\platform-tools;C:\src\android-sdk\emulator;C:\src\mingit\cmd;C:\src\flutter\bin;%PATH%

REM Emulator calismiyorsa onceki oturumdan kalan kilit dosya ve klasorlerini temizle
tasklist /FI "IMAGENAME eq qemu-system-x86_64.exe" 2>nul | find /I "qemu-system-x86_64.exe" >nul
if errorlevel 1 (
    taskkill /F /IM emulator.exe >nul 2>&1
    del /f /q "%USERPROFILE%\.android\avd\Pixel_7_API_34.avd\*.lock" 2>nul
    rmdir /s /q "%USERPROFILE%\.android\avd\Pixel_7_API_34.avd\hardware-qemu.ini.lock" 2>nul
    rmdir /s /q "%USERPROFILE%\.android\avd\Pixel_7_API_34.avd\multiinstance.lock" 2>nul
    echo 1. Pixel 7 Android Emulatoru baslatiliyor...
    start "" "C:\src\android-sdk\emulator\emulator.exe" -avd Pixel_7_API_34 -gpu host
) else (
    echo 1. Acik olan Pixel 7 Android Emulatoru bulundu...
)

echo 2. Sanal telefonun acilmasi bekleniyor...
"C:\src\android-sdk\platform-tools\adb.exe" -e wait-for-device
:wait_boot
for /f "tokens=*" %%a in ('"C:\src\android-sdk\platform-tools\adb.exe" -e shell getprop sys.boot_completed 2^>nul') do set BOOT=%%a
if not "%BOOT%"=="1" (
    ping -n 3 127.0.0.1 >nul
    goto wait_boot
)

echo 3. Kilit ekrani aciliyor ve Hastalik Takip uygulamasi baslatiliyor...
"C:\src\android-sdk\platform-tools\adb.exe" -e shell settings put global heads_up_notifications_enabled 0 >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell settings put global hide_error_dialogs 1 >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell settings put secure anr_show_background 0 >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.gms >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.googlequicksearchbox >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.settings.intelligence >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.apps.wellbeing >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.as >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell pm disable-user --user 0 com.google.android.as.oss >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell cmd overlay disable com.android.internal.systemui.navbar.gestural >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell cmd overlay enable com.android.internal.systemui.navbar.threebutton >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell wm dismiss-keyguard >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell input keyevent 82 >nul 2>&1
"C:\src\android-sdk\platform-tools\adb.exe" -e shell am start -n tr.edu.gedik.yaz305.hastalik_takip/.MainActivity
echo.
echo Emulator ve uygulama acildi! Bu pencereyi kapatabilirsiniz.
ping -n 6 127.0.0.1 >nul
exit /b 0


