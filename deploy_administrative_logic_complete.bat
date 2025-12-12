@echo off
echo ========================================
echo   DEPLOIEMENT LOGIQUE ADMINISTRATIVE
echo   (Operations + Transactions Virtuelles)
echo ========================================
echo.

REM Configuration
set MYSQL_USER=root
set MYSQL_PASS=
set DB_NAME=ucash_db

echo [1/4] Verification des fichiers de migration...
if not exist "database\add_is_administrative_to_operations.sql" (
    echo ERREUR: Migration operations introuvable!
    pause
    exit /b 1
)

if not exist "database\add_is_administrative_to_virtual_transactions.sql" (
    echo ERREUR: Migration virtual_transactions introuvable!
    pause
    exit /b 1
)

echo [2/4] Execution des migrations SQL...
echo.
echo --- Migration table operations ---
mysql -u %MYSQL_USER% %DB_NAME% < database\add_is_administrative_to_operations.sql

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERREUR: Migration operations echouee!
    pause
    exit /b 1
)

echo.
echo --- Migration table virtual_transactions ---
mysql -u %MYSQL_USER% %DB_NAME% < database\add_is_administrative_to_virtual_transactions.sql

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERREUR: Migration virtual_transactions echouee!
    pause
    exit /b 1
)

echo.
echo ✓ Migrations SQL executees avec succes!
echo.

echo [3/4] Deploiement des fichiers PHP vers le serveur...
echo.

REM Copier les fichiers PHP operations
echo Copie operations/upload.php...
copy /Y server\api\sync\operations\upload.php C:\laragon\www\ucash\server\api\sync\operations\upload.php

echo Copie operations/changes.php...
copy /Y server\api\sync\operations\changes.php C:\laragon\www\ucash\server\api\sync\operations\changes.php

REM Copier les fichiers PHP virtual_transactions
echo Copie virtual_transactions/changes.php...
copy /Y server\api\sync\virtual_transactions\changes.php C:\laragon\www\ucash\server\api\sync\virtual_transactions\changes.php

REM Copier la classe SyncManager
echo Copie classes/SyncManager.php...
copy /Y server\classes\SyncManager.php C:\laragon\www\ucash\server\classes\SyncManager.php

echo.
echo [4/4] Test de la migration...
echo.

mysql -u %MYSQL_USER% %DB_NAME% -e "SELECT COUNT(*) as total_ops FROM operations; SELECT COUNT(*) as total_vt FROM virtual_transactions;"

echo.
echo ========================================
echo   DEPLOIEMENT TERMINE!
echo ========================================
echo.
echo FICHIERS MODIFIES:
echo ✓ Flutter:
echo   - lib/models/operation_model.dart
echo   - lib/models/virtual_transaction_model.dart
echo   - lib/widgets/admin_flot_dialog.dart
echo   - lib/services/rapport_cloture_service.dart
echo   - lib/services/cloture_virtuelle_service.dart
echo   - lib/pages/dashboard_admin.dart
echo.
echo ✓ Serveur:
echo   - server/api/sync/operations/upload.php
echo   - server/api/sync/operations/changes.php
echo   - server/api/sync/virtual_transactions/changes.php
echo   - server/classes/SyncManager.php
echo.
echo ✓ Base de donnees:
echo   - operations.is_administrative
echo   - virtual_transactions.is_administrative
echo.
echo PROCHAINES ETAPES:
echo 1. Redemarrer l'application Flutter
echo 2. Tester la creation d'un flot administratif
echo 3. Tester une transaction virtuelle administrative
echo 4. Verifier les rapports de cloture
echo.
pause
