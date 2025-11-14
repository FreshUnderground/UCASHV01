# 🔄 Synchronisation Automatique UCASH - Guide Complet

## 📖 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Utilisation](#utilisation)
6. [API Reference](#api-reference)
7. [Troubleshooting](#troubleshooting)

---

## 📋 Vue d'ensemble

Le système UCASH implémente une **synchronisation automatique bidirectionnelle** toutes les **30 secondes** entre l'application Flutter et le serveur backend PHP/MySQL.

### Fonctionnalités Synchronisées

✅ **Opérations**
- Dépôts (Cash, Airtel Money, M-Pesa, Orange Money)
- Retraits (tous modes de paiement)
- Transferts nationaux
- Transferts internationaux (sortants et entrants)

✅ **Autres Entités**
- Clients
- Agents
- Shops
- Taux de change
- Commissions

### Caractéristiques Principales

- ⏰ **Synchronisation automatique**: Toutes les 30 secondes
- 🔄 **Bidirectionnelle**: App ↔️ Serveur
- 🔐 **Résolution de conflits**: "Last modified wins"
- 🌐 **Mode offline**: Gestion intelligente de la connectivité
- 📊 **Monitoring en temps réel**: Indicateur visuel de statut
- 🔒 **Transactions atomiques**: Garantie de cohérence des données

---

## 🏗️ Architecture

### Diagramme de Flux

```
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION FLUTTER                        │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐     ┌─────────────┐│
│  │ SyncService  │◄────►│ Operations   │────►│ Local DB    ││
│  │ (Timer 30s)  │      │ Transfers    │     │ (SQLite)    ││
│  └──────┬───────┘      │ Depots       │     └─────────────┘│
│         │              │ Retraits     │                     │
│         │              └──────────────┘                     │
└─────────┼──────────────────────────────────────────────────┘
          │
          │ HTTP/JSON (Toutes les 30s)
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    SERVEUR BACKEND (PHP)                     │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐     ┌─────────────┐│
│  │ API Endpoints│◄────►│ SyncManager  │────►│ MySQL DB    ││
│  │ upload.php   │      │ (Conflicts)  │     │ (ucash)     ││
│  │ changes.php  │      └──────────────┘     └─────────────┘│
│  └──────────────┘                                           │
│                                                              │
│  Tables: operations, clients, agents, shops, taux, etc.     │
└─────────────────────────────────────────────────────────────┘
```

### Composants Principaux

#### Côté Flutter

1. **SyncService** (`lib/services/sync_service.dart`)
   - Timer automatique de 30s
   - Gestion upload/download
   - Résolution de conflits

2. **SyncIndicator** (`lib/widgets/sync_indicator.dart`)
   - Widget d'affichage du statut
   - Compte à rebours avant prochaine sync

3. **ManualSyncButton**
   - Bouton pour forcer une sync immédiate

#### Côté Backend

1. **API Endpoints** (`server/api/sync/`)
   - `ping.php` - Test de connectivité
   - `operations/upload.php` - Upload App → Serveur
   - `operations/changes.php` - Download Serveur → App

2. **Database Class** (`server/classes/Database.php`)
   - Singleton PDO
   - Gestion des transactions

3. **Tables MySQL** (`server/database/sync_tables.sql`)
   - Champs de synchronisation
   - Triggers automatiques
   - Vues pour monitoring

---

## 🚀 Installation

### 1. Prérequis

- ✅ Laragon (ou XAMPP/WAMP)
- ✅ MySQL 5.7+
- ✅ PHP 7.4+
- ✅ Flutter 3.0+

### 2. Configuration Base de Données

```bash
# 1. Créer la base de données
mysql -u root -p
```

```sql
CREATE DATABASE IF NOT EXISTS ucash 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE ucash;
```

```bash
# 2. Importer les tables de synchronisation
mysql -u root -p ucash < server/database/sync_tables.sql
```

### 3. Configuration du Backend

Modifier `server/classes/Database.php`:

```php
private $host = 'localhost';
private $dbname = 'ucash';
private $username = 'root';
private $password = ''; // Votre mot de passe MySQL
```

### 4. Configuration de l'Application

Vérifier `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'http://localhost/UCASHV01/server/api';
```

### 5. Tester la Configuration

Ouvrez dans votre navigateur:
```
http://localhost/UCASHV01/server/api/sync/ping.php
```

Réponse attendue:
```json
{
  "success": true,
  "message": "Serveur de synchronisation UCASH opérationnel",
  "version": "1.0.0"
}
```

---

## ⚙️ Configuration

### Intervalle de Synchronisation

Par défaut: **30 secondes**

Pour modifier, dans `lib/services/sync_service.dart`:

```dart
static const Duration _autoSyncInterval = Duration(seconds: 30);

// Exemples:
// Duration(seconds: 15)  // 15 secondes
// Duration(minutes: 1)   // 1 minute
// Duration(seconds: 60)  // 60 secondes
```

### Activation/Désactivation

```dart
final syncService = SyncService();

// Démarrer la synchronisation automatique
await syncService.initialize();

// Arrêter temporairement
syncService.stopAutoSync();

// Redémarrer
syncService.startAutoSync();

// Désactiver complètement
syncService.setAutoSync(false);
```

### Mode de Résolution de Conflits

Stratégie actuelle: **Last Modified Wins**

Pour changer, modifier dans `lib/services/sync_service.dart`:

```dart
Future<bool> _resolveConflict(String tableName, ConflictInfo conflict, String userId) async {
  // Stratégie personnalisée:
  
  // 1. Toujours prendre le serveur
  // return true;
  
  // 2. Toujours prendre le local
  // return false;
  
  // 3. Last modified wins (actuel)
  final useRemote = conflict.remoteModified.isAfter(conflict.localModified);
  return useRemote;
}
```

---

## 💻 Utilisation

### Initialisation dans l'Application

```dart
// Dans main.dart ou au démarrage
import 'package:ucash/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service de synchronisation
  final syncService = SyncService();
  await syncService.initialize(); // Démarre auto-sync toutes les 30s
  
  runApp(MyApp());
}
```

### Affichage du Statut dans l'UI

```dart
import 'package:ucash/widgets/sync_indicator.dart';
import 'package:ucash/services/sync_service.dart';

// Dans votre AppBar ou Dashboard
AppBar(
  title: Text('UCASH'),
  actions: [
    // Indicateur de statut
    SyncIndicator(syncService: SyncService()),
    
    // Bouton de sync manuelle
    ManualSyncButton(
      syncService: SyncService(),
      onSyncComplete: () {
        // Rafraîchir les données
        setState(() {});
      },
    ),
  ],
)
```

### Synchronisation Manuelle

```dart
final syncService = SyncService();

// Synchronisation complète de toutes les tables
final result = await syncService.syncAll();

if (result.success) {
  print('Synchronisation réussie');
} else {
  print('Erreur: ${result.message}');
}

// Synchronisation uniquement des opérations
final success = await syncService.syncOperations();
```

### Écouter les Changements de Statut

```dart
final syncService = SyncService();

// S'abonner au stream
syncService.syncStatusStream.listen((status) {
  switch (status) {
    case SyncStatus.idle:
      print('En attente');
      break;
    case SyncStatus.syncing:
      print('Synchronisation en cours...');
      break;
    case SyncStatus.success:
      print('Synchronisation réussie');
      break;
    case SyncStatus.error:
      print('Erreur de synchronisation');
      break;
  }
});
```

---

## 📚 API Reference

### Endpoints Backend

#### 1. Ping (Test de Connectivité)

```
GET /server/api/sync/ping.php
```

**Réponse:**
```json
{
  "success": true,
  "message": "Serveur de synchronisation UCASH opérationnel",
  "timestamp": "2024-11-08T12:00:00+00:00",
  "server_time": 1699459200,
  "version": "1.0.0"
}
```

#### 2. Upload Opérations (App → Serveur)

```
POST /server/api/sync/operations/upload.php
```

**Request Body:**
```json
{
  "entities": [
    {
      "id": 1,
      "type": "depot",
      "montantBrut": 100.00,
      "montantNet": 97.00,
      "commission": 3.00,
      "clientId": 5,
      "shopSourceId": 1,
      "agentId": 2,
      "modePaiement": "cash",
      "statut": "terminee",
      "dateOp": "2024-11-08T12:00:00Z",
      "lastModifiedAt": "2024-11-08T12:00:00Z",
      "lastModifiedBy": "agent_2"
    }
  ],
  "user_id": "agent_2",
  "timestamp": "2024-11-08T12:00:00Z"
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Synchronisation réussie",
  "uploaded": 1,
  "updated": 0,
  "total": 1,
  "errors": [],
  "timestamp": "2024-11-08T12:00:05+00:00"
}
```

#### 3. Download Opérations (Serveur → App)

```
GET /server/api/sync/operations/changes.php?since=2024-11-08T00:00:00Z&user_id=agent_2
```

**Query Parameters:**
- `since` (optional): Date ISO 8601 pour filtrer les changements
- `user_id`: Identifiant de l'utilisateur
- `limit` (optional): Nombre max de résultats (défaut: 1000)

**Réponse:**
```json
{
  "success": true,
  "message": "Opérations récupérées avec succès",
  "entities": [
    {
      "id": 1,
      "type": "depot",
      "montantBrut": 100.00,
      "montantNet": 97.00,
      "commission": 3.00,
      ...
    }
  ],
  "count": 1,
  "since": "2024-11-08T00:00:00Z",
  "timestamp": "2024-11-08T12:00:05+00:00"
}
```

### Flutter API

#### SyncService

```dart
class SyncService {
  // Initialiser le service (démarre auto-sync)
  Future<void> initialize();
  
  // Synchronisation complète
  Future<SyncResult> syncAll({String? userId});
  
  // Synchronisation des opérations uniquement
  Future<bool> syncOperations();
  
  // Démarrer auto-sync
  void startAutoSync();
  
  // Arrêter auto-sync
  void stopAutoSync();
  
  // Activer/désactiver auto-sync
  void setAutoSync(bool enabled);
  
  // Temps depuis dernière sync
  Duration? getTimeSinceLastSync();
  
  // Temps avant prochaine sync
  Duration? getTimeUntilNextSync();
  
  // Stream de statut
  Stream<SyncStatus> get syncStatusStream;
  
  // Statut actuel
  SyncStatus get currentStatus;
}
```

#### SyncStatus (Enum)

```dart
enum SyncStatus {
  idle,     // En attente
  syncing,  // Synchronisation en cours
  success,  // Réussite
  error,    // Erreur
}
```

#### SyncResult

```dart
class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? details;
}
```

---

## 🔧 Troubleshooting

### Problème 1: "Serveur non disponible"

**Symptômes:**
```
⚠️ Serveur non disponible (mode offline)
```

**Solutions:**

1. Vérifier que Laragon est démarré
```bash
# Services doivent être verts dans Laragon
```

2. Tester l'URL de ping
```
http://localhost/UCASHV01/server/api/sync/ping.php
```

3. Vérifier les credentials MySQL
```php
// server/classes/Database.php
private $username = 'root';
private $password = ''; // Votre mot de passe
```

### Problème 2: "Erreur de synchronisation"

**Symptômes:**
```
❌ Erreur de synchronisation: Exception: ...
```

**Solutions:**

1. Vérifier les logs Flutter
```dart
// Console affiche les détails
📤 Upload operations...
❌ Erreur upload operations: ...
```

2. Vérifier les logs MySQL
```sql
SHOW TABLES; -- Vérifier que les tables existent
SELECT * FROM sync_metadata; -- Vérifier les métadonnées
```

3. Tester manuellement l'API
```bash
# Avec curl ou Postman
curl http://localhost/UCASHV01/server/api/sync/ping.php
```

### Problème 3: "Conflits non résolus"

**Symptômes:**
```
⚠️ Conflit détecté pour 123 dans operations
```

**Solutions:**

1. Forcer une synchronisation manuelle
```dart
await syncService.syncAll();
```

2. Nettoyer les timestamps
```sql
UPDATE operations 
SET last_modified_at = NOW() 
WHERE id = 123;
```

3. Vérifier la stratégie de résolution
```dart
// Modifier dans _resolveConflict()
final useRemote = conflict.remoteModified.isAfter(conflict.localModified);
```

### Problème 4: "Timer ne démarre pas"

**Symptômes:**
- Pas de logs de synchronisation automatique
- Indicateur toujours à "En attente"

**Solutions:**

1. Vérifier l'initialisation
```dart
await syncService.initialize(); // Doit être appelé
```

2. Vérifier que auto-sync est activé
```dart
syncService.setAutoSync(true);
syncService.startAutoSync();
```

3. Vérifier les logs
```
⏰ Démarrage de la synchronisation automatique (intervalle: 30s)
```

### Problème 5: "Données dupliquées"

**Symptômes:**
- Opérations en double dans la base

**Solutions:**

1. Vérifier les contraintes UNIQUE
```sql
SHOW CREATE TABLE operations;
-- Doit avoir des UNIQUE keys si nécessaire
```

2. Nettoyer les doublons
```sql
DELETE o1 FROM operations o1
INNER JOIN operations o2 
WHERE o1.id > o2.id 
AND o1.reference = o2.reference;
```

---

## 📈 Monitoring et Performance

### Vues SQL de Monitoring

```sql
-- Statut de synchronisation
SELECT * FROM v_sync_status;

-- Entités non synchronisées
SELECT * FROM v_unsync_entities;

-- Dernières opérations synchronisées
SELECT * FROM operations 
WHERE is_synced = TRUE 
ORDER BY synced_at DESC 
LIMIT 10;
```

### Logs de Performance

```dart
// Activer les logs détaillés
debugPrint('🔄 Sync started at ${DateTime.now()}');
final stopwatch = Stopwatch()..start();

// ... opérations de sync ...

stopwatch.stop();
debugPrint('✅ Sync completed in ${stopwatch.elapsedMilliseconds}ms');
```

### Optimisations

1. **Index de base de données**
```sql
-- Déjà créés dans sync_tables.sql
CREATE INDEX idx_operations_sync_composite 
ON operations (is_synced, last_modified_at, synced_at);
```

2. **Limitation des résultats**
```dart
// Modifier dans changes.php
$limit = 100; // Au lieu de 1000 pour réduire la charge
```

3. **Sync sélective**
```dart
// Synchroniser uniquement les opérations au lieu de tout
await syncService.syncOperations();
```

---

## 📝 Notes Importantes

1. **Synchronisation toutes les 30s** - Ne pas descendre en dessous de 10s pour éviter la surcharge serveur

2. **Mode offline** - Les opérations sont enregistrées localement et synchronisées automatiquement quand la connexion revient

3. **Résolution de conflits** - "Last modified wins" par défaut, personnalisable

4. **Transactions atomiques** - Garantit la cohérence des données même en cas d'erreur

5. **Performance** - Optimisé avec index MySQL et limitation des résultats

---

## 📞 Support

Pour toute question ou problème:
- Consulter les logs Flutter (console)
- Consulter les logs Apache (Laragon\logs)
- Vérifier la documentation MySQL

---

**Version:** 1.0.0  
**Dernière mise à jour:** 08 novembre 2024  
**Auteur:** UCASH Development Team
