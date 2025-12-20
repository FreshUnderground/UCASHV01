# Configuration de la Synchronisation Automatique UCASH

## 📋 Vue d'ensemble

Le système UCASH dispose d'une synchronisation automatique bidirectionnelle toutes les **30 secondes** pour les:
- ✅ **Transferts** (nationaux et internationaux)
- ✅ **Dépôts** (cash, Airtel Money, M-Pesa, Orange Money)
- ✅ **Retraits** (tous modes de paiement)

## 🗄️ Configuration de la Base de Données

### 1. Créer la base de données

```sql
CREATE DATABASE IF NOT EXISTS ucash 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE ucash;
```

### 2. Exécuter le script de tables

Exécutez le fichier SQL situé dans `server/database/sync_tables.sql`:

```bash
# Méthode 1: Via ligne de commande MySQL
mysql -u root -p ucash < server/database/sync_tables.sql

# Méthode 2: Via phpMyAdmin
# - Ouvrir phpMyAdmin
# - Sélectionner la base "ucash"
# - Onglet "Importer"
# - Choisir le fichier sync_tables.sql
# - Cliquer "Exécuter"
```

### 3. Vérifier la configuration de Database.php

Fichier: `server/classes/Database.php`

```php
private $host = 'localhost';
private $dbname = 'ucash';
private $username = 'root';
private $password = ''; // Modifiez si vous avez un mot de passe MySQL
```

## 🚀 Configuration du Serveur Web (Laragon)

### 1. Démarrer Laragon

- Lancer Laragon
- Démarrer Apache et MySQL
- Vérifier que les services sont actifs (icônes vertes)

### 2. Vérifier l'URL de base

Dans `lib/services/api_service.dart`, l'URL doit être:

```dart
static const String baseUrl = 'https://mahanaimeservice.investee-group.com/server/api';
```

### 3. Tester la connectivité

Ouvrez dans votre navigateur:
```
https://mahanaimeservice.investee-group.com/server/api/sync/ping.php
```

Réponse attendue:
```json
{
  "success": true,
  "message": "Serveur de synchronisation UCASH opérationnel",
  "timestamp": "2024-11-08T...",
  "server_time": 1699459200,
  "version": "1.0.0"
}
```

## ⚙️ Endpoints API Disponibles

### 1. Ping (Test de connectivité)
```
GET https://mahanaimeservice.investee-group.com/server/api/sync/ping.php
```

### 2. Upload des opérations (App → Serveur)
```
POST https://mahanaimeservice.investee-group.com/server/api/sync/operations/upload.php

Body (JSON):
{
  "entities": [
    {
      "id": 1,
      "type": "depot",
      "montantBrut": 100.00,
      "montantNet": 97.00,
      "commission": 3.00,
      "shopSourceId": 1,
      "agentId": 1,
      "modePaiement": "cash",
      "statut": "terminee",
      ...
    }
  ],
  "user_id": "agent_1",
  "timestamp": "2024-11-08T12:00:00Z"
}
```

### 3. Récupération des changements (Serveur → App)
```
GET https://mahanaimeservice.investee-group.com/server/api/sync/operations/changes.php?since=2024-11-08T00:00:00Z&user_id=agent_1

Réponse:
{
  "success": true,
  "entities": [...],
  "count": 10,
  "since": "2024-11-08T00:00:00Z"
}
```

## 🔄 Fonctionnement de la Synchronisation

### Mode Automatique

La synchronisation automatique s'exécute **toutes les 30 secondes**:

1. **Vérification de connectivité** - Ping au serveur
2. **Upload local → serveur** - Envoie les opérations créées/modifiées localement
3. **Download serveur → local** - Récupère les opérations distantes
4. **Résolution de conflits** - "Last modified wins" (le plus récent gagne)
5. **Mise à jour des timestamps** - Marque les entités comme synchronisées

### Activation dans l'application

La synchronisation démarre automatiquement à l'initialisation:

```dart
// Dans main.dart ou au démarrage de l'app
final syncService = SyncService();
await syncService.initialize(); // Démarre auto-sync toutes les 30s
```

### Désactivation temporaire

```dart
// Arrêter la synchronisation automatique
syncService.stopAutoSync();

// Redémarrer
syncService.startAutoSync();
```

## 📊 Suivi de la Synchronisation

### Widget d'indicateur

Utilisez le widget `SyncIndicator` pour afficher le statut:

```dart
import 'package:ucash/widgets/sync_indicator.dart';

// Dans votre dashboard
SyncIndicator(syncService: SyncService())

// Avec bouton de sync manuelle
Row(
  children: [
    SyncIndicator(syncService: SyncService()),
    ManualSyncButton(
      syncService: SyncService(),
      onSyncComplete: () {
        // Rafraîchir les données
      },
    ),
  ],
)
```

### Console de logs

La synchronisation affiche des logs détaillés:

```
🔄 [2024-11-08T12:00:00] Synchronisation automatique - opérations, transferts, dépôts, retraits
📤 Upload des opérations locales...
📥 Download des opérations distantes...
✅ Synchronisation automatique terminée avec succès
```

## 🛠️ Gestion des Conflits

### Stratégie de résolution

**"Last Modified Wins"** - La version la plus récente (timestamp `last_modified_at`) est conservée.

Exemple:
```
Version locale:  last_modified_at = 2024-11-08 12:00:00
Version serveur: last_modified_at = 2024-11-08 12:05:00

→ La version serveur est conservée (plus récente)
```

### Détection de conflits

Un conflit est détecté si:
- L'entité existe des deux côtés (local ET serveur)
- Les timestamps `last_modified_at` sont différents
- Les deux ont été modifiés depuis la dernière sync

## 🔐 Sécurité et Performance

### Transactions atomiques

Toutes les opérations d'upload/download utilisent des transactions SQL:

```php
$db->beginTransaction();
try {
    // Opérations de synchronisation
    $db->commit();
} catch (Exception $e) {
    $db->rollback();
}
```

### Limitation des résultats

Par défaut, maximum **1000 opérations** par requête:

```php
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
```

### Index de performance

Tables optimisées avec index sur:
- `last_modified_at` - Pour les requêtes de changements
- `is_synced` - Pour filtrer les entités non synchronisées
- `synced_at` - Pour le suivi de synchronisation

## 📝 Métadonnées de Synchronisation

### Table sync_metadata

Suit les statistiques de sync:

```sql
SELECT * FROM sync_metadata;
```

Colonnes:
- `table_name` - Nom de la table
- `last_sync_date` - Date de dernière sync
- `sync_count` - Nombre total de synchronisations
- `last_sync_user` - Dernier utilisateur ayant déclenché la sync

### Vues SQL utiles

```sql
-- Statut de synchronisation de toutes les tables
SELECT * FROM v_sync_status;

-- Entités non synchronisées
SELECT * FROM v_unsync_entities;
```

## 🐛 Troubleshooting

### Problème: "Serveur non disponible"

**Solutions:**
1. Vérifier que Laragon est démarré
2. Vérifier que MySQL est actif
3. Tester l'URL de ping dans le navigateur
4. Vérifier les credentials dans `Database.php`

### Problème: "Erreur de synchronisation"

**Solutions:**
1. Vérifier les logs dans la console Flutter
2. Vérifier les logs Apache dans Laragon
3. Tester les endpoints avec Postman
4. Vérifier que les tables existent dans MySQL

### Problème: "Conflits non résolus"

**Solutions:**
1. Forcer une synchronisation manuelle
2. Vérifier les timestamps dans les tables
3. Nettoyer les données de test si nécessaire

## 📈 Monitoring

### Logs côté serveur

Fichier: `C:\laragon\www\UCASHV01\server\logs\sync.log` (à créer)

### Logs côté application

Console Flutter avec filtres:
```bash
flutter run --verbose | grep "Sync"
```

## 🔄 Flux de Synchronisation Complet

```
┌─────────────────┐
│  Application    │
│   (Flutter)     │
└────────┬────────┘
         │
         │ Toutes les 30s
         ▼
┌─────────────────┐
│  Sync Service   │
│  Auto Timer     │
└────────┬────────┘
         │
         ├─► 1. Ping serveur (test connectivité)
         │
         ├─► 2. Upload opérations locales
         │      POST /sync/operations/upload.php
         │
         ├─► 3. Download opérations distantes
         │      GET /sync/operations/changes.php
         │
         ├─► 4. Résolution conflits (last modified wins)
         │
         └─► 5. Update timestamps local + serveur
                 ✅ Sync terminée
```

## ✅ Checklist de Configuration

- [ ] Base de données `ucash` créée
- [ ] Script `sync_tables.sql` exécuté
- [ ] Laragon démarré (Apache + MySQL)
- [ ] Fichier `Database.php` configuré
- [ ] Ping API fonctionne
- [ ] Application Flutter lancée
- [ ] Logs de sync visibles dans la console
- [ ] Widget `SyncIndicator` affiché
- [ ] Première synchronisation réussie

---

**Version:** 1.0.0  
**Dernière mise à jour:** 08 novembre 2024  
**Support:** UCASH Synchronisation System
