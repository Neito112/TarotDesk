@echo off
chcp 65001 > nul
echo ========================================================
echo   TarotDesk Flutter - Kiểm thử & Khởi chạy (Test & Run)
echo ========================================================
echo.

where flutter >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Đã tìm thấy Flutter SDK trong PATH hệ thống.
    goto RUN_CMD
)

echo [!] Lệnh 'flutter' chưa có trong PATH của Windows.
echo Đang quét các vị trí cài đặt Flutter SDK...

if exist "C:\flutter\bin\flutter.bat" set "FLUTTER_BIN=C:\flutter\bin" & goto FOUND
if exist "D:\flutter\bin\flutter.bat" set "FLUTTER_BIN=D:\flutter\bin" & goto FOUND
if exist "E:\flutter\bin\flutter.bat" set "FLUTTER_BIN=E:\flutter\bin" & goto FOUND
if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER_BIN=C:\src\flutter\bin" & goto FOUND
if exist "D:\src\flutter\bin\flutter.bat" set "FLUTTER_BIN=D:\src\flutter\bin" & goto FOUND
if exist "E:\src\flutter\bin\flutter.bat" set "FLUTTER_BIN=E:\src\flutter\bin" & goto FOUND
if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "FLUTTER_BIN=%USERPROFILE%\flutter\bin" & goto FOUND

echo.
set /p FLUTTER_BIN="-> Hãy nhập/dán đường dẫn thư mục 'flutter\bin' của bạn (VD: C:\flutter\bin): "

:FOUND
if not exist "%FLUTTER_BIN%\flutter.bat" (
    echo [LỖI] Đường dẫn không chính xác. Hãy kiểm tra lại Flutter SDK.
    pause
    exit /b 1
)

set "PATH=%FLUTTER_BIN%;%PATH%"

:RUN_CMD
cd /d "%~dp0"
echo 1. Chạy Unit Test...
call flutter test
echo.
echo 2. Cài đặt dependencies...
call flutter pub get
echo.
echo 3. Chạy Ứng dụng TarotDesk...
call flutter run -d windows
pause
