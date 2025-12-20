@echo off
REM ======================================================================
REM UCASH - Script de deploiement des fichiers .htaccess sur serveur
REM ======================================================================
REM Ce script vous guide pour deployer les fichiers .htaccess CORS
REM ======================================================================

echo.
echo ========================================
echo  UCASH - Deploiement CORS (.htaccess)
echo ========================================
echo.

echo FICHIERS A DEPLOYER:
echo   1. server\.htaccess          (racine serveur)
echo   2. server\api\sync\.htaccess (dossier API sync)
echo.

echo INSTRUCTIONS:
echo.
echo 1. Connectez-vous a votre serveur via FTP/SFTP ou cPanel
echo    Serveur: mahanaim.investee-group.com
echo.
echo 2. Uploadez les fichiers suivants:
echo    - Depuis: c:\laragon1\www\UCASHV01\server\.htaccess
echo    - Vers:   /public_html/server/.htaccess (ou votre dossier racine serveur)
echo.
echo    - Depuis: c:\laragon1\www\UCASHV01\server\api\sync\.htaccess
echo    - Vers:   /public_html/server/api/sync/.htaccess
echo.
echo 3. Verifiez que le module Apache mod_headers est active
echo    (Demandez a votre hebergeur si necessaire)
echo.
echo 4. Testez la synchronisation depuis l'application Flutter
echo.

echo.
echo VERIFICATION:
echo Une fois deploye, testez avec:
echo   https://mahanaimeservice.investee-group.com/server/api/sync/ping.php
echo.
echo Si CORS fonctionne, vous devriez voir la reponse JSON sans erreur.
echo.

pause
