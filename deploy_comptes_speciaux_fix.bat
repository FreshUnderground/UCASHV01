@echo off
REM Script de déploiement pour corriger l'endpoint comptes_speciaux
REM Ce script déploie le fichier upload.php corrigé vers le serveur de production

echo ========================================
echo Deploiement de comptes_speciaux/upload.php
echo ========================================
echo.

REM Vérifier que le fichier local existe
if not exist "server\api\sync\comptes_speciaux\upload.php" (
    echo ERREUR: Le fichier upload.php est introuvable localement
    pause
    exit /b 1
)

echo Fichier local trouve: server\api\sync\comptes_speciaux\upload.php
echo.

REM Instructions pour déploiement manuel (à adapter selon votre méthode de déploiement)
echo DEPLOIEMENT REQUIS:
echo.
echo 1. Uploadez le fichier suivant vers votre serveur:
echo    Source: server\api\sync\comptes_speciaux\upload.php
echo    Destination: /server/api/sync/comptes_speciaux/upload.php
echo.
echo 2. Methodes de deploiement:
echo    - FTP/SFTP: Utilisez FileZilla ou WinSCP
echo    - Git: Commitez puis deployez via git pull sur le serveur
echo    - Panneau de controle: Uploadez via le gestionnaire de fichiers
echo.
echo 3. Verifiez que les fichiers suivants existent sur le serveur:
echo    - /server/config/database.php
echo    - /server/classes/Database.php
echo.

REM Si vous utilisez Git, proposer de créer un commit
echo.
echo Voulez-vous creer un commit Git maintenant? (O/N)
set /p create_commit=

if /i "%create_commit%"=="O" (
    echo.
    echo Creation du commit...
    git add server\api\sync\comptes_speciaux\upload.php
    git commit -m "Fix: Amelioration gestion erreurs endpoint comptes_speciaux upload"
    echo.
    echo Commit cree! N'oubliez pas de:
    echo 1. git push origin main
    echo 2. Se connecter au serveur et faire: git pull
    echo.
)

echo.
echo ========================================
echo Instructions de test apres deploiement:
echo ========================================
echo.
echo 1. Testez l'endpoint avec le script de test:
echo    php test_comptes_speciaux_upload.php
echo.
echo 2. Surveillez les logs PHP du serveur pour les messages [COMPTES_SPECIAUX]
echo.
echo 3. Relancez la synchronisation depuis l'application mobile
echo.

pause
