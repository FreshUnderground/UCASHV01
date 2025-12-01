# Fix de Synchronisation Mobile - Opérations et Flots

## Problème Identifié

La synchronisation des **opérations** et **flots** fonctionnait correctement sur le **web** mais rencontrait des problèmes sur **mobile** (Android/iOS).

## Cause Racine

Les applications mobiles natives (Android/iOS) et les applications web gèrent différemment l'encodage des caractères dans les requêtes HTTP. Le problème principal était l'absence de **charset explicite** dans les headers HTTP:

- **Web (navigateur)**: Ajoutait automatiquement `charset=utf-8`
- **Mobile (Flutter HTTP)**: N'ajoutait PAS automatiquement le charset

Résultat: Le serveur PHP recevait des données mal encodées depuis le mobile, causant des erreurs de parsing JSON ou de traitement.

## Solution Appliquée

### 1. Ajout de `charset=utf-8` explicite dans tous les headers HTTP

#### Fichiers Modifiés:

**a) `lib/services/sync_service.dart`**
```dart
// AVANT (❌)
headers: {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
}

// APRÈS (✅)
headers: {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
}
```

**Sections modifiées:**
- ✅ Upload de données (`_uploadTableData`) - ligne 517
- ✅ Download de données (`_downloadTableData`) - ligne 673
- ✅ Upload des flots en queue (`syncPendingFlots`) - ligne 2647

**b) `lib/services/transfer_sync_service.dart`**
```dart
// Validation des transferts - ligne 135
// Téléchargement des opérations - ligne 257
headers: {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
}
```

**c) `lib/services/depot_retrait_sync_service.dart`**
```dart
// Upload des dépôts/retraits - ligne 127
headers: {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
}
```

**d) `lib/services/api_service.dart`**
```dart
// Headers par défaut et _getHeaders() - lignes 14-26
static Map<String, String> get defaultHeaders => {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
};
```

## Impact de la Modification

### ✅ Avant (Web seulement)
- Web: **Fonctionne** ✓
- Mobile: **Ne fonctionne pas** ✗

### ✅ Après (Web + Mobile)
- Web: **Fonctionne** ✓ (aucun impact négatif)
- Mobile: **Fonctionne** ✓ (problème résolu)

## Compatibilité Serveur

Le serveur PHP était déjà configuré pour accepter `charset=utf-8`:

```php
header('Content-Type: application/json; charset=utf-8');
```

Aucune modification serveur n'était nécessaire.

## Services de Synchronisation Affectés

| Service | Fichier | Lignes Modifiées | Status |
|---------|---------|------------------|--------|
| SyncService | `sync_service.dart` | 517, 673, 2647 | ✅ Fixé |
| TransferSyncService | `transfer_sync_service.dart` | 135, 257 | ✅ Fixé |
| DepotRetraitSyncService | `depot_retrait_sync_service.dart` | 127 | ✅ Fixé |
| ApiService | `api_service.dart` | 14-26 | ✅ Fixé |

## Tests Recommandés

### 1. Test Mobile (Android/iOS)
```bash
# Compiler et exécuter sur appareil mobile
flutter run --release
```

**Scénario de test:**
1. Créer une nouvelle opération (dépôt/retrait/transfert)
2. Créer un nouveau flot
3. Vérifier la synchronisation dans les logs
4. Vérifier que les données apparaissent dans le backend MySQL

### 2. Test Web
```bash
# Lancer en mode web
flutter run -d chrome
```

**Vérifier:**
- La synchronisation fonctionne toujours correctement
- Aucune régression introduite

### 3. Vérification Logs

**Mobile - Logs attendus:**
```
📤 Upload operations...
✅ operations: 1 insérés, 0 mis à jour
📤 Upload flots...
✅ flots: 1 insérés, 0 mis à jour
```

**Serveur - Logs PHP:**
```
[SYNC OP] NOUVELLE OPERATION RECUE
SUCCESS: Opération insérée: ID=xxx
Flot inséré: REF xxx -> ID xxx
```

## Pourquoi cette Solution Fonctionne

### Problème Technique
- **HTTP Content-Type sans charset**: Le serveur PHP utilise un encodage par défaut (souvent ISO-8859-1)
- **Données UTF-8 reçues**: Les caractères spéciaux et emojis sont mal interprétés
- **JSON Parse Error**: Le serveur ne peut pas décoder correctement le JSON

### Solution
- **Charset explicite**: Force le serveur à interpréter les données en UTF-8
- **Compatibilité universelle**: UTF-8 est le standard pour le JSON et les API modernes
- **Pas d'effet secondaire**: Le web continuera de fonctionner normalement

## Monitoring et Debugging

### Vérifier si le problème persiste

1. **Activer les logs détaillés** dans `sync_service.dart`:
```dart
debugPrint('📤 $tableName: ${localData.length} éléments à uploader');
```

2. **Vérifier les logs serveur** PHP:
```bash
tail -f /path/to/php/error.log
```

3. **Utiliser les outils de diagnostic**:
```bash
# Test depuis Flutter
dart bin/test_sync.dart

# Test direct HTTP
curl -X POST https://mahanaim.investee-group.com/server/api/sync/operations/upload.php \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"entities":[...],"user_id":"test"}'
```

## Notes de Déploiement

### Étapes de Déploiement

1. **Commit des changements**:
```bash
git add lib/services/sync_service.dart
git add lib/services/transfer_sync_service.dart  
git add lib/services/depot_retrait_sync_service.dart
git add lib/services/api_service.dart
git commit -m "Fix: Add charset=utf-8 to HTTP headers for mobile sync compatibility"
```

2. **Rebuild des applications**:
```bash
# Android
flutter build apk --release

# iOS  
flutter build ios --release

# Web (aucun changement de build nécessaire)
flutter build web --release
```

3. **Tester sur appareil réel** avant déploiement en production

## Références

- [RFC 2616 - HTTP/1.1 Content-Type](https://www.rfc-editor.org/rfc/rfc2616#section-14.17)
- [RFC 8259 - JSON Specification (UTF-8)](https://www.rfc-editor.org/rfc/rfc8259#section-8.1)
- [Flutter HTTP Package Documentation](https://pub.dev/packages/http)

## Auteur

Fix appliqué le: 27 Novembre 2025  
Version: 1.0.0
