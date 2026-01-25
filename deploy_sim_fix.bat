@echo off
REM Script de déploiement du fix SIM Upload 500 Error
REM Ce script copie les fichiers corrigés vers le serveur

echo ========================================
echo DEPLOIEMENT FIX SIM UPLOAD 500 ERROR
echo ========================================
echo.

REM Définir le chemin du serveur (à adapter selon votre configuration)
set SERVER_PATH=C:\laragon1\www\UCASHV01\server

echo Copie des fichiers corrigés...
echo.

REM Vérifier que le chemin serveur existe
if not exist "%SERVER_PATH%" (
    echo ERREUR: Le chemin serveur n'existe pas: %SERVER_PATH%
    echo Veuillez ajuster SERVER_PATH dans ce script.
    pause
    exit /b 1
)

REM Les fichiers sont déjà en place localement, il faut juste les uploader sur le serveur distant
echo.
echo ========================================
echo FICHIERS A DEPLOYER SUR LE SERVEUR:
echo ========================================
echo.
echo 1. server/api/sync/sims/upload.php
echo 2. server/api/sync/sims/changes.php
echo 3. server/diagnose_sim_upload.php
echo 4. server/test_sim_upload_direct.php
echo.

echo ========================================
echo INSTRUCTIONS DE DEPLOIEMENT
echo ========================================
echo.
echo Utilisez votre client FTP/SFTP pour uploader ces fichiers:
echo.
echo SOURCE (local):
echo   %SERVER_PATH%\api\sync\sims\upload.php
echo   %SERVER_PATH%\api\sync\sims\changes.php
echo   %SERVER_PATH%\diagnose_sim_upload.php
echo   %SERVER_PATH%\test_sim_upload_direct.php
echo.
echo DESTINATION (serveur):
echo   https://safdal.investee-group.com/server/api/sync/sims/upload.php
echo   https://safdal.investee-group.com/server/api/sync/sims/changes.php
echo   https://safdal.investee-group.com/server/diagnose_sim_upload.php
echo   https://safdal.investee-group.com/server/test_sim_upload_direct.php
echo.

echo ========================================
echo VERIFICATION POST-DEPLOIEMENT
echo ========================================
echo.
echo Après le déploiement, testez avec:
echo.
echo 1. Diagnostic:
echo    https://safdal.investee-group.com/server/diagnose_sim_upload.php
echo.
echo 2. Test direct:
echo    https://safdal.investee-group.com/server/test_sim_upload_direct.php
echo.
echo 3. Sync depuis Flutter:
echo    Lancez l'application et testez la synchronisation
echo.

pause
