@echo off
echo ========================================
echo    DEPLOIEMENT UCASH PWA SUR LWS
echo    Progressive Web App Complete
echo    addon.investee-group.com
echo ========================================
echo.

echo [1/6] Nettoyage du build precedent...
if exist "build\web" rmdir /s /q "build\web"
echo Build precedent supprime.
echo.

echo [2/6] Generation du build PWA de production...
flutter build web --release --web-renderer html --base-href /
if %errorlevel% neq 0 (
    echo ERREUR: Echec du build Flutter PWA
    pause
    exit /b 1
)
echo Build PWA genere avec succes.
echo.

echo [3/6] Copie du Service Worker avance...
copy /y "web\sw.js" "build\web\sw.js"
if %errorlevel% neq 0 (
    echo ERREUR: Echec de la copie du Service Worker
    pause
    exit /b 1
)
echo Service Worker copie.
echo.

echo [4/6] Verification des fichiers PWA...
if not exist "build\web\manifest.json" (
    echo ERREUR: Manifest PWA manquant
    pause
    exit /b 1
)
if not exist "build\web\sw.js" (
    echo ERREUR: Service Worker manquant
    pause
    exit /b 1
)
if not exist "build\web\.htaccess" (
    echo ERREUR: Configuration Apache manquante
    pause
    exit /b 1
)
echo Tous les fichiers PWA sont presents.
echo.

echo [5/6] Copie de la documentation...
copy /y "UCASH_PWA_DOCUMENTATION.md" "build\web\"
copy /y "DEPLOIEMENT_LWS.md" "build\web\"
echo Documentation copiee.
echo.

echo [6/6] Verification finale...
echo.
echo Fichiers PWA generes dans: build\web\
echo.
dir "build\web" /b | findstr /i "manifest\|sw\|htaccess\|index"
echo.

echo ========================================
echo    BUILD PWA TERMINE AVEC SUCCES !
echo ========================================
echo.
echo UCASH PWA pret pour le deploiement:
echo.
echo ✅ Progressive Web App complete
echo ✅ Service Worker avec cache offline
echo ✅ Manifest avec raccourcis
echo ✅ Configuration Apache optimisee
echo ✅ Support installation native
echo ✅ Fonctionnement online/offline
echo.
echo PROCHAINES ETAPES:
echo.
echo 1. Connectez-vous a votre FTP/SFTP LWS
echo 2. Naviguez vers /www/addon/ (ou /public_html/addon/)
echo 3. Uploadez TOUT le contenu de build\web\
echo 4. Activez le SSL/HTTPS dans votre panel LWS
echo 5. Testez sur https://addon.investee-group.com
echo 6. Testez l'installation PWA sur mobile/desktop
echo.
echo FONCTIONNALITES PWA:
echo • Installation native sur tous appareils
echo • Fonctionnement offline complet
echo • Synchronisation automatique
echo • Performance optimisee
echo • Raccourcis d'application
echo • Notifications push (optionnel)
echo.
echo Consultez UCASH_PWA_DOCUMENTATION.md pour le guide complet.
echo.
pause
