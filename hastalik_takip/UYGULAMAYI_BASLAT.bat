@echo off
chcp 65001 >nul
echo ==========================================================
echo   YAZ305 Mobil Yazilim Gelistirme - Proje 11
echo   Hastalik Takip Mobil Uygulamasi Baslatiliyor...
echo ==========================================================
set PATH=C:\src\mingit\cmd;C:\src\flutter\bin;%PATH%
cd /d "%~dp0"
flutter run -d chrome --web-port 8080
pause
