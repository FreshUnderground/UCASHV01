# 🚀 Guide de Déploiement UCASH

## 📋 Vue d'ensemble

UCASH est une application **PWA Flutter** avec architecture **offline-first** qui nécessite un serveur PHP backend.

---

## 🌐 Déploiement Web (PWA)

### **Option 1: Hébergement sur le Même Serveur (Recommandé)**

Si votre PWA et votre API PHP sont sur le même serveur :

#### **1. Structure de Fichiers**
```
votre-serveur.com/
├── index.html              (PWA Flutter)
├── flutter_bootstrap.js
├── main.dart.js
├── assets/
├── canvaskit/
└── server/
    └── api/
        └── sync/
            └── ping.php
```

#### **2. Configuration**
Dans `lib/config/app_config.dart` :

```dart
if (isProduction) {
  if (kIsWeb) {
    return '/server/api';  // Chemin relatif
  }
}
```

#### **3. Build et Déploiement**
```bash
# Build PWA optimisée
flutter build web --release --web-renderer html

# Copier sur le serveur
cp -r build/web/* /var/www/html/ucash/

# Vérifier les permissions
chmod -R 755 /var/www/html/ucash/server/
```

---

### **Option 2: Serveurs Séparés**

Si PWA et API sont sur des serveurs différents :

#### **Configuration CORS sur le serveur API**

Dans tous vos fichiers PHP (`ping.php`, etc.) :

```php
<?php
header('Access-Control-Allow-Origin: https://votre-pwa.com');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Credentials: true');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}
?>
```

#### **Configuration App**

```dart
if (isProduction) {
  if (kIsWeb) {
    return 'https://api.votre-domaine.com/server/api';  // URL complète
  }
}
```

---

## 📱 Déploiement Mobile (Android/iOS)

### **Configuration API URL**

```dart
if (isProduction) {
  // Mobile en production: URL complète uniquement
  return 'https://api.votre-domaine.com/server/api';
}
```

### **Android**

#### **1. Build APK/AAB**
```bash
# APK (pour tests)
flutter build apk --release

# AAB (pour Google Play Store)
flutter build appbundle --release
```

#### **2. Permissions (android/app/src/main/AndroidManifest.xml)**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### **3. Configuration Réseau**

Si vous utilisez HTTP (non recommandé en production) :

```xml
<application
    android:usesCleartextTraffic="true">
```

### **iOS**

#### **1. Build**
```bash
flutter build ios --release
```

#### **2. Permissions (ios/Runner/Info.plist)**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>votre-domaine.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## 🔧 Configuration pour Développement Local

### **Web (Chrome)**

```dart
// Dans app_config.dart
if (!isProduction) {
  if (kIsWeb) {
    return 'https://mahanaimeservice.investee-group.com/server/api';
  }
}
```

**Commande:**
```bash
flutter run -d chrome --web-port=8080
```

**Accès:** `http://localhost:8080`

---

### **Android Emulator**

```dart
if (!isProduction) {
  return 'http://10.0.2.2/UCASHV01/server/api';  // 10.0.2.2 = localhost sur émulateur
}
```

**Commande:**
```bash
flutter run
```

---

### **Physical Device (Android/iOS)**

**1. Trouver l'IP de votre PC:**
```bash
# Windows
ipconfig

# Mac/Linux
ifconfig
```

**2. Utiliser cette IP:**
```dart
return 'http://192.168.1.100/UCASHV01/server/api';  // Remplacer par votre IP
```

**3. S'assurer que Laragon écoute sur toutes les interfaces:**

Dans Laragon: `Menu > Apache > httpd.conf`

```apache
# Changer
Listen 127.0.0.1:80

# En
Listen 0.0.0.0:80
```

---

## ✅ Vérification Post-Déploiement

### **1. Test de Connectivité API**

**Web:**
```javascript
fetch('https://votre-domaine.com/server/api/sync/ping.php')
  .then(r => r.json())
  .then(console.log);
```

**Mobile (via navigateur du device):**
```
https://votre-domaine.com/server/api/sync/ping.php
```

**Réponse attendue:**
```json
{
  "success": true,
  "message": "Serveur de synchronisation UCASH opérationnel",
  "timestamp": "2025-11-09T09:33:53+00:00",
  "server_time": 1762680833,
  "version": "1.0.0"
}
```

---

### **2. Test de Synchronisation**

1. **Lancez l'app**
2. **Ouvrez les DevTools Console**
3. **Cherchez les logs:**
   ```
   ✅ Service de synchronisation initialisé
   🌐 Mode Web: Test direct de connexion au serveur...
   ✅ Serveur accessible (Web)
   ```

4. **Activez l'auto-sync** depuis l'interface ou le widget de configuration

5. **Vérifiez dans la console:**
   ```
   🚀 === DÉBUT SYNCHRONISATION BIDIRECTIONNELLE ===
   ✅ === SYNCHRONISATION TERMINÉE AVEC SUCCÈS ===
   ```

---

## 🔐 Sécurité en Production

### **1. HTTPS Obligatoire**
- ✅ Utilisez un certificat SSL (Let's Encrypt gratuit)
- ❌ Jamais de HTTP en production

### **2. Configuration Apache/Nginx**

**Apache (.htaccess):**
```apache
# Forcer HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]

# Protéger server/api contre accès direct
<Directory /var/www/html/ucash/server/>
    Options -Indexes
    AllowOverride All
</Directory>
```

**Nginx:**
```nginx
# Forcer HTTPS
server {
    listen 80;
    server_name votre-domaine.com;
    return 301 https://$server_name$request_uri;
}

# Configuration HTTPS
server {
    listen 443 ssl;
    server_name votre-domaine.com;
    
    ssl_certificate /etc/letsencrypt/live/votre-domaine.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/votre-domaine.com/privkey.pem;
    
    root /var/www/html/ucash;
    index index.html;
    
    location /server/api/ {
        try_files $uri $uri/ =404;
    }
}
```

### **3. Variables d'Environnement**

Créez un fichier `server/config/env.php` :
```php
<?php
// NE PAS COMMITER CE FICHIER
define('DB_HOST', 'localhost');
define('DB_NAME', 'ucash_prod');
define('DB_USER', 'ucash_user');
define('DB_PASS', 'VOTRE_MOT_DE_PASSE_FORT');
define('JWT_SECRET', 'VOTRE_SECRET_JWT');
?>
```

---

## 📊 Monitoring

### **Logs à Surveiller**

**Flutter (Web Console):**
- Erreurs de synchronisation
- Temps de réponse API
- Opérations en attente

**PHP (server/logs/):**
```php
error_log("Sync: " . $message, 3, "/var/www/logs/ucash_sync.log");
```

**Apache/Nginx:**
```bash
tail -f /var/log/apache2/error.log
tail -f /var/log/nginx/error.log
```

---

## 🛠️ Dépannage

### **Problème: "Serveur non disponible"**

**Causes possibles:**
1. ❌ URL incorrecte dans `app_config.dart`
2. ❌ CORS mal configuré
3. ❌ Firewall bloque le port
4. ❌ PHP/Apache non démarré

**Solution:**
```bash
# Tester le serveur
curl https://votre-domaine.com/server/api/sync/ping.php

# Vérifier les logs
tail -f /var/log/apache2/error.log
```

---

### **Problème: CORS Error (Web)**

**Erreur:**
```
Access to XMLHttpRequest has been blocked by CORS policy
```

**Solution:**

Dans **TOUS** vos fichiers PHP :
```php
header('Access-Control-Allow-Origin: https://votre-pwa.com');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
```

---

### **Problème: Connexion lente sur Mobile**

**Causes:**
1. Serveur géographiquement éloigné
2. Timeout trop court

**Solution:**

Dans `app_config.dart` :
```dart
static const Duration httpTimeout = Duration(seconds: 60);  // Augmenter
```

---

## 📝 Checklist de Déploiement

### **Avant Production**

- [ ] URL API configurée dans `app_config.dart`
- [ ] HTTPS activé sur le serveur
- [ ] CORS configuré correctement
- [ ] Base de données MySQL créée et migrée
- [ ] Credentials PHP sécurisés dans `env.php`
- [ ] Logs activés (PHP + Apache/Nginx)
- [ ] Permissions fichiers correctes (`chmod 755`)
- [ ] Test de ping API réussi
- [ ] Test de synchronisation réussi
- [ ] Mode offline testé
- [ ] PWA installable testée
- [ ] Notifications push configurées (optionnel)

### **Post-Déploiement**

- [ ] Monitoring des logs activé
- [ ] Backup automatique de la BD
- [ ] Plan de rollback préparé
- [ ] Documentation utilisateur créée
- [ ] Formation agents effectuée

---

## 📞 Support

**Logs en Production:**
```bash
# Activer mode debug temporairement
flutter run --release --dart-define=DEBUG_MODE=true
```

**Version de l'App:**
```dart
debugPrint('UCASH ${AppConfig.appVersion} - ${AppConfig.platform}');
```

---

**🎉 Bonne chance avec le déploiement !**
