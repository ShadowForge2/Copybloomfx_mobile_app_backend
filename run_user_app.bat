@echo off
cd /d "C:\flutter_projects\CopyBloomFX users and admin apps\bloomfx_user_app"
flutter run -d chrome --web-port=50000 --web-launch-url=http://127.0.0.1:50000 --web-user-data-dir="C:\flutter_projects\CopyBloomFX users and admin apps\.chrome_user"
pause
