@echo off
REM Grokly Quick Commerce Platform - Setup Script for Windows
REM This script sets up and runs the Flutter quick commerce application

cls
echo ======================================
echo   Grokly - Quick Commerce Platform
echo   Setup ^& Launch Script (Windows)
echo ======================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X Flutter is not installed. Please install Flutter first.
    echo   Visit: https://flutter.dev/docs/get-started/install
    exit /b 1
)

REM Check Flutter version
echo + Checking Flutter installation...
flutter --version
echo.

REM Navigate to project directory
cd /d "%~dp0"
echo + Project directory: %cd%
echo.

REM Clean previous builds
echo - Cleaning previous build...
call flutter clean
if %ERRORLEVEL% EQU 0 (
    echo + Clean complete
) else (
    echo X Clean failed
    exit /b 1
)
echo.

REM Get dependencies
echo - Installing dependencies...
call flutter pub get
if %ERRORLEVEL% EQU 0 (
    echo + Dependencies installed
) else (
    echo X Failed to install dependencies
    exit /b 1
)
echo.

REM Check for available devices
echo - Checking available devices...
flutter devices
echo.

REM Run the app
echo - Launching Grokly Quick Commerce Platform...
echo.
call flutter run

REM Show instructions
echo.
echo ======================================
echo   Launch Complete!
echo ======================================
echo.
echo Testing Credentials:
echo   Email: test@example.com (or any email)
echo   Password: password123 (or any password)
echo.
echo Features to Test:
echo   1. Sign up a new account
echo   2. Browse products
echo   3. Search/filter by category
echo   4. Add items to cart
echo   5. Complete checkout
echo   6. Confirm order
echo.
echo Documentation:
echo   - IMPLEMENTATION_SUMMARY.md
echo   - COMMERCE_README.md
echo   - SETUP_GUIDE.md
echo   - DEVELOPMENT_CHECKLIST.md
echo.
echo ======================================
pause
