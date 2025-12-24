# 🔧 Fix: Synchronisation comptes_speciaux échouée (HTTP 400)

## 📋 Problème

La synchronisation de la table `comptes_speciaux` échoue systématiquement avec une erreur HTTP 400, et le serveur retourne une page HTML d'erreur au lieu d'une réponse JSON.

### Symptômes

```
❌ Erreur upload comptes_speciaux: Exception: Erreur HTTP 400: 
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
```

### Logs Flutter

```
💰 COMPTES_SPECIAUX: Total en mémoire: 60
📤 COMPTES_SPECIAUX: 60/60 non synchronisés
📤 comptes_speciaux: 60 enregistrement(s) non synchronisé(s) trouvé(s)
! Validation non implémentée pour comptes_speciaux
📤 comptes_speciaux: Sending 60 entities
! Erreur HTTP comptes_speciaux: 400
❌ Erreur upload comptes_speciaux: Exception: Erreur HTTP 400: [HTML error page]
```

## 🔍 Cause du problème

Le HTTP 400 avec une réponse HTML au lieu de JSON indique que le fichier PHP rencontre une **erreur fatale** avant de pouvoir définir les headers JSON et retourner une réponse appropriée.

Causes possibles:
1. ❌ Le fichier `upload.php` n'existe pas sur le serveur de production
2. ❌ Les fichiers requis (`Database.php`, `database.php`) sont introuvables
3. ❌ Une erreur PHP fatale (syntax error, class not found, etc.)
4. ❌ Le serveur n'a pas été déployé avec les derniers fichiers

## ✅ Solution implémentée

### 1. Amélioration de `server/api/sync/comptes_speciaux/upload.php`

#### A. Vérification de l'existence des fichiers requis

```php
// Vérifier que le fichier de config existe
if (!file_exists(__DIR__ . '/../../../config/database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier de configuration database.php introuvable',
        'path_checked' => __DIR__ . '/../../../config/database.php'
    ]);
    exit;
}

// Vérifier que la classe Database existe
if (!file_exists(__DIR__ . '/../../../classes/Database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier Database.php introuvable',
        'path_checked' => __DIR__ . '/../../../classes/Database.php'
    ]);
    exit;
}
```

#### B. Logs détaillés pour diagnostic

```php
error_log("[COMPTES_SPECIAUX] Upload request received");
error_log("[COMPTES_SPECIAUX] Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("[COMPTES_SPECIAUX] Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
error_log("[COMPTES_SPECIAUX] Input length: " . strlen($input));
```

#### C. Validation améliorée des données JSON

```php
if (empty($input)) {
    throw new Exception('Aucune donnée reçue dans la requête');
}

$data = json_decode($input, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    throw new Exception('Erreur de décodage JSON: ' . json_last_error_msg());
}
```

### 2. Scripts de diagnostic créés

#### `test_comptes_speciaux_upload.php`
Script pour tester l'endpoint directement avec des données de test:
- Envoie une requête POST avec un compte spécial de test
- Affiche les headers de réponse
- Décode et affiche la réponse JSON ou HTML

#### `check_comptes_speciaux_table.php`
Script pour vérifier la structure de la table:
- Vérifie l'existence de la table
- Affiche la structure des colonnes
- Affiche le nombre d'enregistrements
- Liste quelques exemples

### 3. Script de déploiement

`deploy_comptes_speciaux_fix.bat` - Guide le déploiement du correctif

## 📝 Instructions de déploiement

### Étape 1: Vérifier localement

```bash
# Vérifier que les fichiers existent
dir server\api\sync\comptes_speciaux\upload.php
dir server\config\database.php
dir server\classes\Database.php
```

### Étape 2: Déployer vers production

**Option A: Via Git (recommandé)**

```bash
git add server\api\sync\comptes_speciaux\upload.php
git commit -m "Fix: Amélioration gestion erreurs endpoint comptes_speciaux upload"
git push origin main

# Sur le serveur
ssh user@mahanaimeservice.investee-group.com
cd /path/to/ucash
git pull
```

**Option B: Via FTP/SFTP**

1. Ouvrez FileZilla ou WinSCP
2. Connectez-vous à `mahanaimeservice.investee-group.com`
3. Uploadez `server/api/sync/comptes_speciaux/upload.php` vers `/server/api/sync/comptes_speciaux/upload.php`

**Option C: Via le panneau de contrôle d'hébergement**

1. Connectez-vous au panneau de contrôle
2. Ouvrez le gestionnaire de fichiers
3. Naviguez vers `/server/api/sync/comptes_speciaux/`
4. Uploadez le fichier `upload.php`

### Étape 3: Vérifier le déploiement

#### 3A. Tester l'endpoint

```bash
# Depuis votre machine locale
php test_comptes_speciaux_upload.php
```

#### 3B. Vérifier la structure de la table

```bash
php check_comptes_speciaux_table.php
```

#### 3C. Vérifier les logs du serveur

Sur le serveur, surveillez les logs PHP:
```bash
tail -f /var/log/php/error.log | grep COMPTES_SPECIAUX
```

### Étape 4: Tester la synchronisation

1. Ouvrez l'application mobile
2. Déclenchez une synchronisation manuelle
3. Vérifiez les logs Flutter pour:
   ```
   ✅ comptes_speciaux: X insérés, Y mis à jour
   ```

## 🔍 Diagnostic des erreurs

### Si l'erreur persiste après déploiement

#### 1. Vérifier que le fichier est bien déployé

```bash
# Sur le serveur
cat /path/to/server/api/sync/comptes_speciaux/upload.php | head -20
# Vous devriez voir les nouveaux logs "[COMPTES_SPECIAUX]"
```

#### 2. Vérifier les permissions

```bash
# Sur le serveur
ls -la /path/to/server/api/sync/comptes_speciaux/upload.php
# Devrait être: -rw-r--r-- (644)

# Si nécessaire, corriger:
chmod 644 /path/to/server/api/sync/comptes_speciaux/upload.php
```

#### 3. Vérifier que la table existe

```sql
-- Depuis MySQL
SHOW TABLES LIKE 'comptes_speciaux';
DESCRIBE comptes_speciaux;
```

#### 4. Consulter les logs détaillés

Les nouveaux logs devraient maintenant apparaître dans les logs PHP du serveur:

```
[COMPTES_SPECIAUX] Upload request received
[COMPTES_SPECIAUX] Request method: POST
[COMPTES_SPECIAUX] Content-Type: application/json; charset=utf-8
[COMPTES_SPECIAUX] Input length: 15420
[COMPTES_SPECIAUX] JSON décodé avec succès
```

## 🎯 Validation du correctif

### Checklist de validation

- [ ] Le fichier `upload.php` corrigé est déployé sur le serveur
- [ ] Les fichiers requis existent (`database.php`, `Database.php`)
- [ ] La table `comptes_speciaux` existe dans la base de données
- [ ] Les permissions des fichiers sont correctes (644)
- [ ] L'endpoint retourne du JSON (pas du HTML) en cas d'erreur
- [ ] Les logs `[COMPTES_SPECIAUX]` apparaissent dans les logs PHP
- [ ] La synchronisation mobile réussit sans erreur HTTP 400
- [ ] Les données sont bien insérées dans la table

### Tests de non-régression

```bash
# 1. Tester l'endpoint directement
php test_comptes_speciaux_upload.php

# 2. Vérifier la table
php check_comptes_speciaux_table.php

# 3. Synchroniser depuis l'app mobile
# Vérifier les logs Flutter pour: ✅ comptes_speciaux: X insérés

# 4. Vérifier les données dans la base
mysql -u user -p -e "SELECT COUNT(*) FROM comptes_speciaux;"
```

## 📊 Résumé des modifications

| Fichier | Type de modification | Description |
|---------|---------------------|-------------|
| `server/api/sync/comptes_speciaux/upload.php` | Amélioration | Ajout vérifications fichiers + logs détaillés |
| `test_comptes_speciaux_upload.php` | Nouveau | Script de test de l'endpoint |
| `check_comptes_speciaux_table.php` | Nouveau | Script de vérification de la table |
| `deploy_comptes_speciaux_fix.bat` | Nouveau | Script de déploiement |

## 🔄 Prochaines étapes

1. **Déployer** le correctif sur le serveur de production
2. **Tester** l'endpoint avec le script de test
3. **Vérifier** que la synchronisation mobile fonctionne
4. **Surveiller** les logs pour détecter d'autres problèmes
5. **Implémenter** la validation manquante pour `comptes_speciaux` (warning: `! Validation non implémentée pour comptes_speciaux`)

## 💡 Note importante

Le message `! Validation non implémentée pour comptes_speciaux` dans les logs indique que la validation côté client n'est pas encore implémentée. Bien que cela ne bloque pas la synchronisation, il serait bon d'ajouter cette validation dans `sync_service.dart` pour garantir l'intégrité des données avant l'upload.

---

**Date de création:** 2025-12-02  
**Version:** 1.0  
**Auteur:** Qoder AI Assistant
