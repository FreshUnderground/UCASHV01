# 🔧 Synchronisation UCASH - Guide de Référence Rapide

## 🎯 Quick Wins Implémentés (Phase 1)

### ✅ 1. Fenêtre de Chevauchement (Overlap Window)

**Fichier**: `lib/services/sync_service.dart`  
**Ligne**: 603

**Problème résolu**: Données manquantes lors de modifications concurrentes

**Configuration**:
```dart
// lib/config/sync_config.dart
static const Duration overlapWindow = Duration(seconds: 60);
static const bool enableOverlapWindow = true; // ⚠️ Toujours true!
```

**Logs à surveiller**:
```
🔄 operations: Overlap window applied (60s before ...)
📥 operations: Downloading since ... (with 60s overlap)
```

---

### ✅ 2. Headers HTTP Charset UTF-8

**Fichiers modifiés**:
- `lib/services/sync_service.dart` (ligne 517, 673, 2647)
- `lib/services/transfer_sync_service.dart` (ligne 135, 257)
- `lib/services/depot_retrait_sync_service.dart` (ligne 127)
- `lib/services/api_service.dart` (ligne 14-26)

**Problème résolu**: Sync mobile échouée (charset manquant)

**Changement**:
```dart
// AVANT
headers: {'Content-Type': 'application/json'}

// APRÈS
headers: {'Content-Type': 'application/json; charset=utf-8'}
```

---

### ✅ 3. Configuration Centralisée

**Nouveau fichier**: `lib/config/sync_config.dart`

**Usage**:
```dart
import '../config/sync_config.dart';

// Utiliser les constantes
final interval = SyncConfig.fastSyncInterval;
final overlap = SyncConfig.overlapWindow;

// Logger la config au démarrage
SyncConfig.logConfiguration();
```

---

## 📊 Architecture de Sync

```
┌─────────────────────────────────────────┐
│     RobustSyncService (Orchestrateur)   │
│  ┌───────────┐         ┌─────────────┐  │
│  │ FAST SYNC │         │  SLOW SYNC  │  │
│  │  (2 min)  │         │  (10 min)   │  │
│  └───────────┘         └─────────────┘  │
└─────────────────────────────────────────┘
           │                     │
           ▼                     ▼
    ┌──────────────┐      ┌──────────────┐
    │ SyncService  │      │ SyncService  │
    │  - Upload    │      │  - Upload    │
    │  - Download  │      │  - Download  │
    └──────────────┘      └──────────────┘
           │                     │
           ▼                     ▼
    ┌──────────────┐      ┌──────────────┐
    │  Opérations  │      │    Shops     │
    │    Flots     │      │    Agents    │
    │   Clients    │      │ Commissions  │
    │    Sims      │      │   Clôtures   │
    └──────────────┘      └──────────────┘
```

---

## 🔄 Intervalles de Sync

| Type | Fréquence | Tables |
|------|-----------|--------|
| **FAST** | 2 min | operations, flots, clients, comptes_speciaux, sims, virtual_transactions |
| **SLOW** | 10 min | shops, agents, commissions, cloture_caisse, document_headers |
| **QUEUE** | Immédiat | Opérations en attente (mode offline) |

---

## 📝 Logs Importants

### Logs de Succès
```
✅ FAST SYNC terminé en 3s: 8 OK, 0 erreurs
✅ operations: 45 éléments reçus du serveur
✅ Flot REF123 synchronisé avec succès
```

### Logs d'Avertissement
```
⚠️ operations: 5 éléments invalides ignorés
⚠️ Tables échouées: audit_log, reconciliations
⏸️ FAST SYNC déjà en cours, ignoré
```

### Logs d'Erreur
```
❌ Erreur upload operations: Connection timeout
❌ Shop ID non initialisé, impossible de synchroniser
❌ Erreur globale FAST SYNC: Exception...
```

---

## 🛠️ Debugging

### Vérifier État de Sync

```dart
// Dans votre code
final stats = RobustSyncService().getStats();
print(stats);

// Output
{
  'isEnabled': true,
  'isOnline': true,
  'lastFastSync': '2025-11-27T12:00:00Z',
  'fastSyncSuccess': 150,
  'fastSyncErrors': 3,
  'failedFastTables': ['audit_log'],
}
```

### Forcer Sync Manuelle

```dart
// Sync complète (FAST + SLOW)
await RobustSyncService().syncNow();

// Sync rapide seulement
await RobustSyncService()._performFastSync(isInitial: true);
```

### Vérifier Queue Offline

```dart
final syncService = SyncService();
print('Opérations en attente: ${syncService._pendingOperations.length}');
print('Flots en attente: ${syncService._pendingFlots.length}');
```

---

## ⚠️ Problèmes Courants

### 1. Données Manquantes

**Symptôme**: Utilisateur ne voit pas les nouvelles données

**Solution**:
```dart
// Vérifier dans sync_config.dart
static const enableOverlapWindow = true; // ✅ DOIT être true

// Vérifier logs
grep "Overlap window applied" app.log
```

---

### 2. Sync Lente

**Symptôme**: Sync prend > 10 secondes

**Diagnostic**:
```dart
// Mesurer durée
final startTime = DateTime.now();
await syncService.syncAll();
final duration = DateTime.now().difference(startTime);
print('Durée: ${duration.inSeconds}s');
```

**Solutions**:
1. Vérifier connexion réseau
2. Implémenter pagination (Phase 2)
3. Activer compression (Phase 3)

---

### 3. Queue Trop Grande

**Symptôme**: `_pendingOperations.length > 100`

**Solutions**:
```dart
// Forcer sync immédiate
await syncService.syncPendingData();

// Vérifier connectivité
final isOnline = await Connectivity().checkConnectivity();
if (isOnline == ConnectivityResult.none) {
  print('⚠️ Mode offline - queue normale');
}
```

---

### 4. Erreurs de Charset Mobile

**Symptôme**: Sync échoue sur Android/iOS mais pas sur web

**Vérification**:
```dart
// Chercher dans le code
grep "charset=utf-8" lib/services/*.dart

// Devrait montrer:
lib/services/sync_service.dart:    'Content-Type': 'application/json; charset=utf-8',
lib/services/transfer_sync_service.dart:    'Content-Type': 'application/json; charset=utf-8',
```

**Si manquant**:
```dart
// Ajouter dans headers HTTP
headers: {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
}
```

---

## 📊 Métriques à Surveiller

### Taux de Succès

```dart
final stats = RobustSyncService().getStats();
final totalFast = stats['fastSyncSuccess'] + stats['fastSyncErrors'];
final successRate = (stats['fastSyncSuccess'] / totalFast) * 100;

if (successRate < 80) {
  print('⚠️ Taux de succès faible: $successRate%');
}
```

### Dernière Sync

```dart
final lastSync = stats['lastFastSync'];
if (lastSync != null) {
  final duration = DateTime.now().difference(DateTime.parse(lastSync));
  if (duration > Duration(minutes: 10)) {
    print('⚠️ Aucune sync depuis ${duration.inMinutes} minutes');
  }
}
```

---

## 🔧 Ajustements Rapides

### Changer Intervalle de Sync

```dart
// lib/config/sync_config.dart

// Plus rapide (pour tests)
static const fastSyncInterval = Duration(seconds: 30);

// Plus lent (économie batterie)
static const fastSyncInterval = Duration(minutes: 5);

// RECOMMANDÉ (production)
static const fastSyncInterval = Duration(minutes: 2);
```

### Ajuster Fenêtre de Chevauchement

```dart
// Connexion très instable
static const overlapWindow = Duration(seconds: 120);

// Connexion stable
static const overlapWindow = Duration(seconds: 60);

// Connexion parfaite (tests seulement)
static const overlapWindow = Duration(seconds: 30);
```

### Activer/Désactiver Logs

```dart
// Développement - Logs détaillés
static bool get enableDetailedLogs => true;

// Production - Logs minimaux
static bool get enableDetailedLogs => false;

// Auto selon environnement
static bool get enableDetailedLogs => kDebugMode;
```

---

## 🧪 Tests Rapides

### Test 1: Vérifier Sync

```bash
# Démarrer app
flutter run

# Observer logs
# Devrait voir:
🚀 FAST SYNC - Début
✅ FAST SYNC terminé en 3s: 8 OK, 0 erreurs
```

### Test 2: Vérifier Overlap

```bash
# Chercher dans logs
grep "overlap" app.log

# Devrait montrer:
🔄 operations: Overlap window applied (60s before ...)
📥 operations: Downloading since ... (with 60s overlap)
```

### Test 3: Test Mode Offline

```bash
# 1. Désactiver WiFi/Data
# 2. Créer opération
# 3. Observer logs:
📋 [QUEUE] Ajout opération à la queue

# 4. Réactiver réseau
# 5. Observer logs:
🔄 Retour en ligne détecté
✅ Queue opérations synchronisée
```

---

## 📞 Support

### Fichiers de Documentation

| Fichier | Usage |
|---------|-------|
| `AMELIORATIONS_SYNCHRONISATION_FR.md` | Guide complet (français) |
| `SYNC_OPTIMIZATION_RECOMMENDATIONS.md` | Guide technique (anglais) |
| `MOBILE_SYNC_FIX.md` | Fix charset mobile |
| `lib/config/sync_config.dart` | Configuration centralisée |
| `SYNC_README.md` | Documentation architecture |

### Commandes Utiles

```bash
# Tester sync depuis terminal
dart bin/test_sync.dart

# Logs en temps réel
flutter logs | grep "SYNC"

# Erreurs seulement
flutter logs | grep "❌"

# Stats de sync
flutter logs | grep "terminé"
```

---

## 🎯 Checklist Avant Production

- [ ] `enableOverlapWindow = true` dans `sync_config.dart`
- [ ] Headers charset UTF-8 dans tous les services
- [ ] Logs détaillés désactivés (`enableDetailedLogs = false`)
- [ ] Intervalles de sync appropriés (2 min FAST, 10 min SLOW)
- [ ] Tests de sync avec 5+ utilisateurs simultanés
- [ ] Vérification mode offline → online
- [ ] Monitoring activé pour alertes

---

**Version**: 2.0  
**Dernière mise à jour**: 27 Novembre 2025
