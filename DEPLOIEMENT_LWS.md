# 🚀 Guide de Déploiement UCASH sur LWS (addon.investee-group.com)

## 📋 Prérequis

- Accès FTP/SFTP à votre hébergement LWS
- Domaine configuré : addon.investee-group.com
- Application UCASH compilée avec succès

## 🔧 Étapes de Déploiement

### 1. Préparation des Fichiers

Les fichiers à déployer se trouvent dans : `build/web/`

**Contenu du dossier :**
```
build/web/
├── index.html              # Page principale
├── main.dart.js            # Application Flutter compilée
├── flutter_service_worker.js
├── manifest.json           # Configuration PWA
├── .htaccess              # Configuration Apache (créé)
├── assets/                # Assets de l'application
├── canvaskit/            # Moteur de rendu Flutter
├── icons/                # Icônes de l'application
└── favicon.png           # Favicon
```

### 2. Configuration du Serveur LWS

#### A. Connexion FTP/SFTP
- **Serveur** : Votre serveur LWS
- **Utilisateur** : Votre nom d'utilisateur LWS
- **Mot de passe** : Votre mot de passe LWS
- **Port** : 21 (FTP) ou 22 (SFTP)

#### B. Répertoire de Déploiement
- Naviguez vers le dossier : `/www/addon/`
- Ou selon votre configuration LWS : `/public_html/addon/`

### 3. Upload des Fichiers

#### Méthode 1 : FTP Client (FileZilla, WinSCP)
1. Connectez-vous à votre serveur LWS
2. Naviguez vers le dossier addon
3. Uploadez TOUT le contenu de `build/web/` vers le serveur
4. Assurez-vous que les permissions sont correctes (755 pour les dossiers, 644 pour les fichiers)

#### Méthode 2 : Gestionnaire de Fichiers LWS
1. Connectez-vous à votre espace client LWS
2. Accédez au gestionnaire de fichiers
3. Naviguez vers le dossier addon
4. Uploadez les fichiers via l'interface web

### 4. Configuration Spécifique LWS

#### A. Vérification du .htaccess
Le fichier `.htaccess` a été créé automatiquement avec :
- Compression GZIP activée
- Cache optimisé pour les assets Flutter
- Redirection HTTPS
- Gestion des routes SPA
- Headers de sécurité

#### B. Configuration du Domaine
Assurez-vous que `addon.investee-group.com` pointe vers le bon dossier :
- Dans votre panel LWS, configurez le sous-domaine `addon`
- Pointez-le vers le dossier où vous avez uploadé les fichiers

### 5. Configuration Base de Données (Si nécessaire)

Si vous utilisez la synchronisation MySQL :

#### A. Création de la Base de Données
1. Dans votre panel LWS, créez une nouvelle base MySQL
2. Notez les informations de connexion :
   - Serveur : `mysql-[votre-serveur].lws-hosting.com`
   - Base : `[votre-base]`
   - Utilisateur : `[votre-utilisateur]`
   - Mot de passe : `[votre-mot-de-passe]`

#### B. Upload des Scripts PHP
Si vous avez des scripts PHP pour la synchronisation :
1. Créez un dossier `api/` dans votre répertoire web
2. Uploadez tous les fichiers PHP du dossier `server/`
3. Modifiez `server/config/database.php` avec vos informations LWS

### 6. Test et Vérification

#### A. Test de Base
1. Accédez à `https://addon.investee-group.com`
2. Vérifiez que l'application se charge correctement
3. Testez la navigation entre les pages
4. Vérifiez la responsivité sur différents appareils

#### B. Test des Fonctionnalités
1. **Connexion** : Testez avec admin/admin123
2. **Navigation** : Vérifiez tous les onglets
3. **Opérations** : Testez la création d'opérations
4. **Responsive** : Testez sur mobile/tablet/desktop

#### C. Vérification des Performances
1. Utilisez les outils de développement du navigateur
2. Vérifiez les temps de chargement
3. Contrôlez la compression GZIP
4. Testez le cache des assets

### 7. Optimisations Post-Déploiement

#### A. SSL/HTTPS
- Activez le certificat SSL dans votre panel LWS
- Vérifiez que la redirection HTTPS fonctionne

#### B. Monitoring
- Configurez les logs d'erreur Apache
- Surveillez les performances via les outils LWS

#### C. Sauvegarde
- Configurez des sauvegardes automatiques
- Testez la restauration

## 🔧 Dépannage

### Problèmes Courants

#### 1. Page Blanche
- Vérifiez les permissions des fichiers
- Contrôlez les logs d'erreur Apache
- Assurez-vous que tous les fichiers sont uploadés

#### 2. Erreur 404 sur les Routes
- Vérifiez que le `.htaccess` est présent
- Contrôlez la configuration Apache de LWS
- Testez les règles de réécriture

#### 3. Assets Non Chargés
- Vérifiez les chemins dans `index.html`
- Contrôlez les permissions des dossiers `assets/`
- Testez la compression GZIP

#### 4. Problèmes de Performance
- Activez la compression
- Optimisez le cache
- Vérifiez la configuration du serveur LWS

### Commandes Utiles

```bash
# Vérifier les permissions (via SSH si disponible)
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

# Test de compression GZIP
curl -H "Accept-Encoding: gzip" -I https://addon.investee-group.com
```

## 📞 Support

En cas de problème :
1. **Documentation LWS** : Consultez la documentation officielle
2. **Support LWS** : Contactez le support technique
3. **Logs** : Vérifiez les logs d'erreur dans votre panel

## ✅ Checklist de Déploiement

- [ ] Build de production créé (`flutter build web --release`)
- [ ] Fichiers uploadés sur le serveur LWS
- [ ] Configuration `.htaccess` en place
- [ ] Domaine `addon.investee-group.com` configuré
- [ ] SSL/HTTPS activé
- [ ] Test de l'application réussi
- [ ] Performance optimisée
- [ ] Sauvegarde configurée

## 🎯 URL Finale

Une fois déployé, votre application UCASH sera accessible à :
**https://addon.investee-group.com**

---

*Guide créé pour le déploiement de UCASH v1.0.0 sur LWS Hosting*
