@echo off
REM Script de test de la synchronisation UCASH (Windows)
REM Usage: test_sync.bat

echo ============================================
echo    Test de la Synchronisation UCASH
echo ============================================
echo.

REM Configuration
set BASE_URL=http://localhost/UCASHV01/server/api/sync

REM Test 1: Ping serveur
echo [1/5] Test de connectivite au serveur...
curl -s "%BASE_URL%/ping.php" > ping_result.json
if %ERRORLEVEL% EQU 0 (
    echo [OK] Serveur accessible
    type ping_result.json
) else (
    echo [ERREUR] Serveur non accessible
    goto :cleanup
)
echo.

REM Test 2: Upload d'une operation de test
echo [2/5] Test d'upload d'une operation...

REM Generer le JSON de test
echo { > test_operation.json
echo   "entities": [ >> test_operation.json
echo     { >> test_operation.json
echo       "id": 9999, >> test_operation.json
echo       "type": "depot", >> test_operation.json
echo       "montantBrut": 100.00, >> test_operation.json
echo       "montantNet": 97.00, >> test_operation.json
echo       "commission": 3.00, >> test_operation.json
echo       "clientId": 1, >> test_operation.json
echo       "shopSourceId": 1, >> test_operation.json
echo       "agentId": 1, >> test_operation.json
echo       "modePaiement": "cash", >> test_operation.json
echo       "statut": "terminee", >> test_operation.json
echo       "reference": "TEST_SYNC_WIN_001", >> test_operation.json
echo       "notes": "Test de synchronisation Windows", >> test_operation.json
echo       "dateOp": "2024-11-08T12:00:00Z", >> test_operation.json
echo       "lastModifiedAt": "2024-11-08T12:00:00Z", >> test_operation.json
echo       "lastModifiedBy": "test_script_win" >> test_operation.json
echo     } >> test_operation.json
echo   ], >> test_operation.json
echo   "user_id": "test_script_win", >> test_operation.json
echo   "timestamp": "2024-11-08T12:00:00Z" >> test_operation.json
echo } >> test_operation.json

curl -s -X POST "%BASE_URL%/operations/upload.php" ^
    -H "Content-Type: application/json" ^
    -d @test_operation.json > upload_result.json

if %ERRORLEVEL% EQU 0 (
    echo [OK] Upload execute
    type upload_result.json
) else (
    echo [ERREUR] Erreur lors de l'upload
)
echo.

REM Test 3: Download des operations
echo [3/5] Test de download des operations...
curl -s "%BASE_URL%/operations/changes.php?user_id=test_script_win&limit=5" > download_result.json

if %ERRORLEVEL% EQU 0 (
    echo [OK] Download execute
    type download_result.json
) else (
    echo [ERREUR] Erreur lors du download
)
echo.

REM Test 4: Verification MySQL (si mysql.exe est dans le PATH)
echo [4/5] Test de connexion MySQL...
mysql -u root -e "SELECT COUNT(*) as total_operations FROM operations;" ucash 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [OK] Base de donnees accessible
) else (
    echo [AVERTISSEMENT] MySQL non accessible via ligne de commande
    echo Verifiez que mysql.exe est dans le PATH ou utilisez phpMyAdmin
)
echo.

REM Test 5: Affichage du statut
echo [5/5] Statut de synchronisation...
mysql -u root -e "SELECT * FROM v_sync_status;" ucash 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [OK] Metadonnees de sync accessibles
) else (
    echo [INFO] Vue v_sync_status non accessible via CLI
    echo Utilisez phpMyAdmin: SELECT * FROM v_sync_status;
)
echo.

:cleanup
REM Nettoyage
if exist ping_result.json del ping_result.json
if exist test_operation.json del test_operation.json
if exist upload_result.json del upload_result.json
if exist download_result.json del download_result.json

echo ============================================
echo Tests de synchronisation termines
echo ============================================
echo.
echo Prochaines etapes:
echo   1. Demarrer Laragon (Apache + MySQL)
echo   2. Lancer l'application Flutter
echo   3. Observer la synchronisation automatique (toutes les 30s)
echo   4. Verifier l'indicateur de sync dans l'AppBar
echo.
echo Pour tester manuellement l'API:
echo   http://localhost/UCASHV01/server/api/sync/ping.php
echo.

pause
