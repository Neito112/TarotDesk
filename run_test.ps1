# TarotDesk Test & Run Script for PowerShell
$ErrorActionPreference = "Continue"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   TarotDesk Flutter - Kiem thu & Khoi chay (Test & Run)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if flutter is in PATH
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    Write-Host "[OK] Da tim thay Flutter SDK trong PATH he thong." -ForegroundColor Green
} else {
    Write-Host "[!] Lenh 'flutter' chua duoc them vao PATH he thong." -ForegroundColor Yellow
    Write-Host "Dang tim kiem Flutter SDK tren may tinh..." -ForegroundColor Yellow

    $possiblePaths = @(
        "C:\flutter\bin",
        "D:\flutter\bin",
        "E:\flutter\bin",
        "C:\src\flutter\bin",
        "D:\src\flutter\bin",
        "E:\src\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "$env:USERPROFILE\src\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin"
    )

    $foundPath = $null
    foreach ($p in $possiblePaths) {
        if (Test-Path "$p\flutter.bat") {
            $foundPath = $p
            break
        }
    }

    if ($foundPath) {
        Write-Host "[OK] Da tim thay Flutter SDK tai: $foundPath" -ForegroundColor Green
        $env:PATH = "$foundPath;$env:PATH"
    } else {
        Write-Host ""
        Write-Host "[HUONG DAN CAI DAT FLUTTER SDK]" -ForegroundColor Red
        Write-Host "May tinh cua ban chua duoc cai dat Flutter SDK hoac chua duoc giai nen vao dung thu muc." -ForegroundColor Yellow
        Write-Host "Buoc 1: Tai Flutter SDK cho Windows tai: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White
        Write-Host "Buoc 2: Giai nen file zip vao C:\flutter (hoac D:\flutter)" -ForegroundColor White
        Write-Host ""
        $userPath = Read-Host "Nguoi dung: Neu ban da tai Flutter SDK o thu muc khac, hay nhap duong dan 'flutter\bin' tai đây"
        if ($userPath -and (Test-Path "$userPath\flutter.bat")) {
            $env:PATH = "$userPath;$env:PATH"
            Write-Host "[OK] Da ket noi voi Flutter SDK tai: $userPath" -ForegroundColor Green
        } else {
            Write-Host "[LOI] Khong the thuc hien vi may tinh chua duoc cai dat Flutter SDK." -ForegroundColor Red
            return
        }
    }
}

$targetDir = "$PSScriptRoot\tarot_desk_flutter"
if (Test-Path $targetDir) {
    Set-Location $targetDir
}

Write-Host ""
Write-Host "1. Dang chay Unit Test kiem tra ma nguon..." -ForegroundColor Cyan
flutter test

Write-Host ""
Write-Host "2. Dang cai dat thu vien dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

Write-Host ""
Write-Host "3. Khoi chay Ung dung TarotDesk..." -ForegroundColor Cyan
Write-Host "   - Target mac dinh: Web / Chrome" -ForegroundColor Yellow
flutter run -d chrome
