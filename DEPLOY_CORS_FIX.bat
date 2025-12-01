@echo off
REM ======================================================================
REM UCASH - Script de deploiement de la correction CORS + LOGIQUE SYNC
REM ======================================================================
REM Ce script liste les fichiers a uploader sur le serveur de production
REM ======================================================================

echo.
echo ========================================
echo  UCASH - CORRECTION CORS + SYNC LOGIC
echo ========================================
echo.

echo NOUVELLE LOGIQUE DE SYNCHRONISATION:
echo.
echo   ADMIN:  Telecharge TOUTES les operations (tous shops)
echo.
echo   AGENT:  Telecharge les operations ou:
echo           1. shop_source_id = son_shop (operations creees dans son shop)
echo           2. shop_destination_id = son_shop ET type = transfert
echo              (transferts entrants a valider)
echo.
echo ========================================

echo FICHIERS A DEPLOYER SUR LE SERVEUR:
echo.
echo   1. server/api/sync/.htaccess
echo      Destination: /server/api/sync/.htaccess
echo.
echo   2. server/api/sync/operations/changes.php (ANCIEN - a remplacer)
echo      Destination: /server/api/sync/operations/changes.php
echo.
echo   3. server/api/sync/operations/getoperations.php (NOUVEAU)
echo      Destination: /server/api/sync/operations/getoperations.php
echo.
echo   4. server/.htaccess
echo      Destination: /server/.htaccess
echo.

echo ========================================
echo  INSTRUCTIONS DE DEPLOIEMENT
echo ========================================
echo.
echo 1. Connectez-vous a votre serveur via FTP/SFTP ou cPanel
echo    Serveur: mahanaim.investee-group.com
echo.
echo 2. Uploadez les fichiers suivants:
echo.
echo    FICHIER 1: .htaccess (dossier sync)
echo    - Local:  %CD%\server\api\sync\.htaccess
echo    - Serveur: /public_html/server/api/sync/.htaccess
echo.
echo    FICHIER 2: changes.php (operations - REMPLACER L'ANCIEN)
echo    - Local:  %CD%\server\api\sync\operations\changes.php
echo    - Serveur: /public_html/server/api/sync/operations/changes.php
echo.
echo    FICHIER 3: getoperations.php (NOUVEAU FICHIER)
echo    - Local:  %CD%\server\api\sync\operations\getoperations.php
echo    - Serveur: /public_html/server/api/sync/operations/getoperations.php
echo.
echo    FICHIER 4: .htaccess (racine server)
echo    - Local:  %CD%\server\.htaccess
echo    - Serveur: /public_html/server/.htaccess
echo.
echo 3. Verifiez que mod_headers et mod_rewrite sont actives sur Apache
echo    (Normalement deja actif sur la plupart des hebergeurs)
echo.
echo 4. Testez la synchronisation depuis l'application Flutter
echo.
echo ========================================

echo.
echo OUVRIR LE DOSSIER DES FICHIERS A DEPLOYER?
echo.
pause

REM Ouvrir l'explorateur Windows sur le dossier server
explorer "%CD%\server\api\sync"

echo.
echo ========================================
echo APRES LE DEPLOIEMENT:
echo ========================================
echo.
echo 1. Relancez l'application Flutter
echo 2. Faites une synchronisation
echo 3. Les operations devraient maintenant se telecharger!
echo.
echo Si le probleme persiste:
echo - Verifiez que les fichiers .htaccess sont bien upload
echo - Verifiez les permissions des fichiers (644 pour .htaccess)
echo - Consultez les logs Apache du serveur
echo.
pause
