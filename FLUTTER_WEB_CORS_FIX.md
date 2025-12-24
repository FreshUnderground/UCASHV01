# SOLUTION ERREUR HTTP FLUTTER WEB - CORS

## PROBLÈME IDENTIFIÉ
Stack trace indique une erreur HTTP dans Flutter Web lors de la synchronisation `cloture_caisse` (tentative 4/5).
Erreur dans `packages/http/src/browser_client.dart` avec échecs répétés et retry automatique.

## CAUSE PRINCIPALE
Problème CORS (Cross-Origin Resource Sharing) et timeout réseau entre Flutter Web et le serveur API distant.

## SOLUTIONS IMPLÉMENTÉES

### 1. Configuration Apache (.htaccess)
Fichier créé : `server/.htaccess`
- Headers CORS automatiques
- Gestion des requêtes OPTIONS (preflight)
- Configuration PHP optimisée

### 2. Configuration PHP (cors_config.php)
Fichier créé : `server/cors_config.php`
- Headers CORS standardisés
- Fonctions utilitaires pour JSON
- Gestion d'erreurs HTTP
- Validation des données POST

## ÉTAPES DE RÉSOLUTION

### Étape 1 : Vérifier Laragon
```bash
# Vérifier que Laragon est démarré
# Apache/Nginx : VERT
# MySQL : VERT
```

### Étape 2 : Tester l'accès serveur
```
URL à tester : http://localhost/UCASHV01/server/
Doit afficher la structure des fichiers ou une page d'accueil
```

### Étape 3 : Intégrer cors_config.php
Ajouter au début de chaque fichier API PHP :
```php
<?php
require_once 'cors_config.php';
// Votre code API ici...
?>
```

### Étape 4 : Redémarrer les services
1. Arrêter Laragon
2. Redémarrer Laragon
3. Tester à nouveau l'application Flutter Web

## FICHIERS À MODIFIER

### Exemple d'intégration dans un fichier API :
```php
<?php
// Inclure la configuration CORS
require_once 'cors_config.php';

// Votre logique API
try {
    $data = validatePostData(['field1', 'field2']);
    
    // Traitement...
    
    sendJsonResponse([
        'success' => true,
        'data' => $result
    ]);
    
} catch (Exception $e) {
    sendErrorResponse($e->getMessage(), 500);
}
?>
```

## VÉRIFICATIONS POST-INSTALLATION

### 1. Test CORS
```javascript
// Dans la console du navigateur
fetch('http://localhost/UCASHV01/server/test.php')
  .then(response => response.json())
  .then(data => console.log(data))
  .catch(error => console.error('Erreur:', error));
```

### 2. Headers de réponse attendus
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept
```

## ALTERNATIVE SI PROBLÈME PERSISTE

### Option 1 : Proxy de développement
Modifier `web/index.html` pour ajouter :
```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self' http://localhost:* data: gap: https://ssl.gstatic.com 'unsafe-eval'; style-src 'self' 'unsafe-inline'; media-src *">
```

### Option 2 : Configuration Chrome pour développement
Lancer Chrome avec :
```bash
chrome.exe --user-data-dir="C:/temp/chrome_dev" --disable-web-security --disable-features=VizDisplayCompositor
```

## DIAGNOSTIC AVANCÉ

### Vérifier les logs Apache
```
Laragon/logs/apache_error.log
Laragon/logs/apache_access.log
```

### Console navigateur
```
F12 → Network → Voir les requêtes échouées
F12 → Console → Voir les erreurs CORS
```

## CONTACT SUPPORT
Si le problème persiste après ces étapes :
1. Vérifier la version de Laragon
2. Tester avec un autre navigateur
3. Vérifier les paramètres de pare-feu
4. Consulter la documentation Flutter Web CORS
