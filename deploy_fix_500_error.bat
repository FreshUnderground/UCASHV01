@echo off
echo ========================================
echo    FIX UCASH WEB DEPLOYMENT ERRORS
echo    Resolving flutter.js 500 Error
echo    safdal.investee-group.com
echo ========================================
echo.

echo [1/7] Cleaning previous builds...
if exist "build\web" rmdir /s /q "build\web"
echo Previous build removed.
echo.

echo [2/7] Upgrading Flutter (optional but recommended)...
echo This ensures you have the latest web build tools.
choice /C YN /M "Do you want to upgrade Flutter now (Y/N)"
if errorlevel 2 goto skip_upgrade
flutter upgrade
flutter clean
:skip_upgrade
echo.

echo [3/7] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo.

echo [4/7] Building web app with correct settings...
echo Using canvaskit renderer for better compatibility
flutter build web --release --web-renderer canvaskit --base-href /
if %errorlevel% neq 0 (
    echo ERROR: Flutter build failed
    echo.
    echo TROUBLESHOOTING:
    echo 1. Run: flutter doctor
    echo 2. Check for errors in your Dart code
    echo 3. Ensure all dependencies are compatible
    pause
    exit /b 1
)
echo Web build completed successfully.
echo.

echo [5/7] Verifying critical files...
set "MISSING_FILES="

if not exist "build\web\index.html" set "MISSING_FILES=!MISSING_FILES! index.html"
if not exist "build\web\flutter.js" set "MISSING_FILES=!MISSING_FILES! flutter.js"
if not exist "build\web\manifest.json" set "MISSING_FILES=!MISSING_FILES! manifest.json"
if not exist "build\web\.htaccess" set "MISSING_FILES=!MISSING_FILES! .htaccess"

if not "%MISSING_FILES%"=="" (
    echo ERROR: Missing critical files: %MISSING_FILES%
    echo.
    echo Build may be incomplete. Please check Flutter installation.
    pause
    exit /b 1
)

echo All critical files present:
echo   ✓ index.html
echo   ✓ flutter.js
echo   ✓ manifest.json
echo   ✓ .htaccess
echo.

echo [6/7] Checking icons...
if exist "build\web\icons\Icon-144.png" (
    echo   ✓ Icon-144.png found
) else (
    echo   ⚠ Warning: Icon-144.png missing
)
if exist "build\web\icons\Icon-192.png" (
    echo   ✓ Icon-192.png found
) else (
    echo   ⚠ Warning: Icon-192.png missing
)
echo.

echo [7/7] Copying documentation...
copy /y "FLUTTER_WEB_500_ERROR_FIX.md" "build\web\" >nul 2>&1
copy /y "DEPLOIEMENT_LWS.md" "build\web\" >nul 2>&1
echo.

echo ========================================
echo    BUILD COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo Build location: build\web\
echo.
echo CRITICAL FILES TO UPLOAD:
echo.
echo 📁 Root Directory:
echo    • index.html
echo    • flutter.js          ← MUST be present (fixes 500 error)
echo    • flutter_bootstrap.js
echo    • main.dart.js
echo    • manifest.json
echo    • .htaccess           ← MUST be uploaded (often hidden)
echo.
echo 📁 Folders:
echo    • assets/             ← Complete folder
echo    • canvaskit/          ← Complete folder  
echo    • icons/              ← Including Icon-144.png
echo.
echo ========================================
echo    UPLOAD INSTRUCTIONS
echo ========================================
echo.
echo 1. Connect to FTP/SFTP:
echo    Server: Your LWS FTP server
echo    Path: /www/ or /public_html/
echo.
echo 2. Upload EVERYTHING from build\web\
echo    • Show hidden files to see .htaccess
echo    • Use BINARY mode for uploads
echo    • Verify flutter.js uploaded correctly
echo.
echo 3. Set file permissions (if possible):
echo    • Directories: 755
echo    • Files: 644
echo.
echo 4. Test the deployment:
echo    • Open: https://safdal.investee-group.com
echo    • Check browser console (F12)
echo    • Verify: No "flutter.js 500 error"
echo    • Verify: No "_flutter is not defined"
echo.
echo 5. If still getting 500 error on flutter.js:
echo    • Check server error logs
echo    • Verify .htaccess was uploaded
echo    • Contact LWS support
echo    • See FLUTTER_WEB_500_ERROR_FIX.md
echo.
echo ========================================
echo    VERIFICATION CHECKLIST
echo ========================================
echo.
echo After upload, verify these URLs load:
echo ✓ https://safdal.investee-group.com/
echo ✓ https://safdal.investee-group.com/flutter.js
echo ✓ https://safdal.investee-group.com/icons/Icon-144.png
echo ✓ https://safdal.investee-group.com/manifest.json
echo.
echo Expected result in browser console:
echo ✓ No 500 errors
echo ✓ No "_flutter is not defined"
echo ✓ Application loads and runs
echo.
echo For detailed troubleshooting, see:
echo FLUTTER_WEB_500_ERROR_FIX.md (copied to build\web\)
echo.
pause
