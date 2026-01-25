@echo off
echo ========================================
echo    DEPLOIEMENT UCASH SUR LWS
echo    addon.investee-group.com
echo ========================================
echo.

echo [1/4] Nettoyage du build precedent...
if exist "build\web" rmdir /s /q "build\web"
echo Build precedent supprime.
echo.

echo [2/4] Creation du build de production...
flutter build web --release --web-renderer canvaskit --base-href /
if %errorlevel% neq 0 (
    echo ERREUR: Echec du build Flutter
    pause
    exit /b 1
)
echo Build de production cree avec succes.
echo.

echo [3/4] Ajout de la configuration LWS...
copy /y "DEPLOIEMENT_LWS.md" "build\web\"
echo Configuration LWS ajoutee.
echo.

echo [4/4] Preparation des fichiers pour upload...
echo.
echo ========================================
echo    BUILD TERMINE AVEC SUCCES !
echo ========================================
echo.
echo Fichiers prets pour le deploiement dans: build\web\
echo.
echo PROCHAINES ETAPES:
echo 1. Connectez-vous a votre FTP LWS
echo 2. Naviguez vers le dossier /www/addon/
echo 3. Uploadez TOUT le contenu de build\web\
echo 4. Testez sur https://addon.investee-group.com
echo.
echo Consultez DEPLOIEMENT_LWS.md pour le guide complet.
echo.
pause
