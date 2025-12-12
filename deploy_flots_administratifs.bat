@echo off
echo ========================================
echo   DEPLOIEMENT FLOTS ADMINISTRATIFS
echo ========================================
echo.

REM Configuration
set MYSQL_USER=root
set MYSQL_PASS=
set DB_NAME=ucash_db
set MIGRATION_FILE=database\add_is_administrative_to_operations.sql

echo [1/3] Verification de la migration SQL...
if not exist "%MIGRATION_FILE%" (
    echo ERREUR: Fichier de migration introuvable: %MIGRATION_FILE%
    pause
    exit /b 1
)

echo [2/3] Execution de la migration SQL...
echo.
mysql -u %MYSQL_USER% %DB_NAME% < %MIGRATION_FILE%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERREUR: La migration SQL a echoue!
    echo Verifiez que MySQL est demarre et que la base de donnees existe.
    pause
    exit /b 1
)

echo.
echo ✓ Migration SQL executee avec succes!
echo.

echo [3/3] Deploiement des fichiers PHP vers le serveur...
echo.

REM Copier les fichiers PHP mis à jour
echo Copie de upload.php...
copy /Y server\api\sync\operations\upload.php C:\laragon\www\ucash\server\api\sync\operations\upload.php

echo Copie de changes.php...
copy /Y server\api\sync\operations\changes.php C:\laragon\www\ucash\server\api\sync\operations\changes.php

echo.
echo ========================================
echo   DEPLOIEMENT TERMINE!
echo ========================================
echo.
echo PROCHAINES ETAPES:
echo 1. Redemarrer l'application Flutter
echo 2. Tester la creation d'un flot administratif
echo 3. Verifier la synchronisation avec le serveur
echo 4. Controler le rapport de cloture
echo.
pause
