# Fix pour les erreurs de synchronisation SIMS et VIRTUAL_TRANSACTIONS

## Problème Identifié

Les erreurs HTTP 500 lors de la synchronisation des tables `sims` et `virtual_transactions` étaient causées par :

1. **Endpoints API manquants** : Le dossier `server/api/sync/virtual_transactions/` n'existait pas
2. **Tables potentiellement manquantes** : Les tables `sims` et `virtual_transactions` pourraient ne pas exister dans la base de données ou manquer de colonnes nécessaires
3. **Gestion incomplète dans sync_service.dart** : Les cas `sims` et `virtual_transactions` n'étaient pas gérés dans les méthodes `_insertLocalEntity` et `_updateLocalEntity`

## Corrections Apportées

### 1. Création des endpoints API pour virtual_transactions

**Fichiers créés :**
- `server/api/sync/virtual_transactions/changes.php` - Endpoint pour récupérer les changements
- `server/api/sync/virtual_transactions/upload.php` - Endpoint pour uploader les transactions

Ces fichiers suivent la même structure que les autres endpoints de synchronisation.

### 2. Script d'initialisation de la base de données

**Fichier créé :**
- `server/init_sims_virtual_transactions.php`

Ce script :
- Vérifie l'existence des tables `sims`, `virtual_transactions` et `sim_movements`
- Crée les tables si elles n'existent pas
- Ajoute les colonnes de synchronisation manquantes (`last_modified_at`, `last_modified_by`, `is_synced`, `synced_at`)
- Affiche un rapport détaillé de l'initialisation

### 3. Mise à jour de sync_service.dart

**Modifications :**
- Ajout des imports pour `SimModel` et `VirtualTransactionModel`
- Ajout du cas `sims` dans `_insertLocalEntity()` pour gérer l'insertion des SIMs
- Ajout du cas `virtual_transactions` dans `_insertLocalEntity()` pour gérer l'insertion des transactions virtuelles
- Ajout du cas `sims` dans `_updateLocalEntity()` pour gérer la mise à jour des SIMs
- Ajout du cas `virtual_transactions` dans `_updateLocalEntity()` pour gérer la mise à jour des transactions virtuelles

## Instructions de Déploiement

### Étape 1 : Déployer les nouveaux fichiers API

Transférer les fichiers suivants sur le serveur :
```
server/api/sync/virtual_transactions/changes.php
server/api/sync/virtual_transactions/upload.php
```

### Étape 2 : Initialiser la base de données

Exécuter le script d'initialisation sur le serveur :
```bash
php server/init_sims_virtual_transactions.php
```

Ou ouvrir le script dans un navigateur :
```
https://mahanaimeservice.investee-group.com/server/init_sims_virtual_transactions.php
```

**Vérifications attendues :**
- ✅ Table SIMS vérifiée/créée
- ✅ Table VIRTUAL_TRANSACTIONS vérifiée/créée
- ✅ Table SIM_MOVEMENTS vérifiée/créée
- Colonnes manquantes ajoutées si nécessaire

### Étape 3 : Recompiler l'application Flutter

L'application Flutter a été mise à jour pour gérer correctement les SIMs et transactions virtuelles :
```bash
flutter clean
flutter pub get
flutter build web
```

### Étape 4 : Vérification

Après le déploiement :

1. **Vérifier les endpoints API :**
   - `https://mahanaimeservice.investee-group.com/server/api/sync/sims/changes.php?since=2020-01-01T00:00:00.000`
   - `https://mahanaimeservice.investee-group.com/server/api/sync/virtual_transactions/changes.php?since=2020-01-01T00:00:00.000`

2. **Tester la synchronisation :**
   - Se connecter à l'application
   - Déclencher une synchronisation manuelle
   - Vérifier que les erreurs HTTP 500 ne se produisent plus
   - Vérifier les logs : les messages "✅ Tables critiques synchronisées" devraient apparaître

3. **Vérifier la base de données :**
   ```sql
   SHOW COLUMNS FROM sims;
   SHOW COLUMNS FROM virtual_transactions;
   SELECT COUNT(*) FROM sims;
   SELECT COUNT(*) FROM virtual_transactions;
   ```

## Structure des Tables

### Table SIMS
```sql
- id (INT, PRIMARY KEY)
- numero (VARCHAR(20), UNIQUE)
- operateur (VARCHAR(50))
- shop_id (INT)
- shop_designation (VARCHAR(255))
- solde_initial (DECIMAL(15,2))
- solde_actuel (DECIMAL(15,2))
- statut (ENUM: active, suspendue, perdue, desactivee)
- motif_suspension (TEXT)
- date_creation (DATETIME)
- date_suspension (DATETIME)
- cree_par (VARCHAR(100))
- last_modified_at (DATETIME) ← Important pour la sync
- last_modified_by (VARCHAR(100))
- is_synced (TINYINT(1))
- synced_at (DATETIME)
```

### Table VIRTUAL_TRANSACTIONS
```sql
- id (INT, PRIMARY KEY)
- reference (VARCHAR(100), UNIQUE)
- montant_virtuel (DECIMAL(15,2))
- frais (DECIMAL(15,2))
- montant_cash (DECIMAL(15,2))
- devise (VARCHAR(10))
- sim_numero (VARCHAR(20))
- shop_id (INT)
- shop_designation (VARCHAR(255))
- agent_id (INT)
- agent_username (VARCHAR(100))
- client_nom (VARCHAR(255))
- client_telephone (VARCHAR(20))
- statut (ENUM: enAttente, validee, annulee)
- date_enregistrement (DATETIME)
- date_validation (DATETIME)
- notes (TEXT)
- last_modified_at (DATETIME) ← Important pour la sync
- last_modified_by (VARCHAR(100))
- is_synced (TINYINT(1))
- synced_at (DATETIME)
```

## Logs de Diagnostic

Pour diagnostiquer d'éventuels problèmes, vérifier les logs serveur :
- Logs PHP : `/var/log/apache2/error.log` ou `/var/log/php/error.log`
- Chercher les messages :
  - `[SIMs Changes]`
  - `[Virtual Transactions Changes]`
  - `[SIMs Upload]`
  - `[Virtual Transactions Upload]`

## Prochaines Étapes

1. **Tester en production** : Vérifier que la synchronisation fonctionne correctement
2. **Monitorer les performances** : Observer le temps de synchronisation avec ces nouvelles tables
3. **Créer des SIMs et transactions de test** : Valider le flux complet de synchronisation

## Rollback en Cas de Problème

Si des problèmes surviennent :

1. **Désactiver temporairement les nouvelles tables dans la sync :**
   Modifier `lib/services/sync_service.dart` ligne 246 :
   ```dart
   // Commenter temporairement sims et virtual_transactions
   final dependentTables = ['agents', 'clients', 'operations', 'taux', 'commissions', 'comptes_speciaux', 'document_headers', 'cloture_caisse', 'flots'/*, 'sims', 'virtual_transactions'*/];
   ```

2. **Restaurer la version précédente :**
   ```bash
   git revert HEAD
   flutter build web
   ```

## Contact

Pour toute question ou problème lié à ce correctif, consulter :
- Logs détaillés de l'application (Console navigateur)
- Logs serveur PHP
- Base de données MySQL/MariaDB
