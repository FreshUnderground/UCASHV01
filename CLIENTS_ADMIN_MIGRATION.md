# Migration: Clients Admin Globaux

## 📋 Problème

Lorsqu'un administrateur crée un client dans UCASH, il peut vouloir créer un client **global** accessible depuis tous les shops, sans l'associer à un shop spécifique. Cependant, la validation actuelle rejetait ces clients car `shop_id` était obligatoire (NOT NULL).

### Erreur rencontrée
```
❌ Validation: shop_id manquant pour client 1764306514903
⚠️ clients: Données invalides pour ID 1764306514903 - ignorées
```

## ✅ Solution

Cette migration permet aux administrateurs de créer des clients avec `shop_id = NULL`, rendant ces clients **globaux** et accessibles depuis n'importe quel shop.

## 🔄 Fichiers modifiés

### 1. Base de données
- **`database/alter_clients_allow_null_shop.sql`**: Script SQL de migration
- **`server/migrate_clients_admin.php`**: Interface web pour exécuter la migration

### 2. Code Flutter (Client)
- **`lib/services/sync_service.dart`** (ligne 400-420):
  - ✅ Validation modifiée pour permettre `shop_id = NULL` pour les admins
  - ✅ Message informatif ajouté lors de la synchronisation

### 3. Code PHP (Serveur)
- **`server/api/sync/clients/upload.php`** (ligne 88-102):
  - ✅ Suppression du fallback `shop_id = 1` par défaut
  - ✅ Acceptation de `shop_id = NULL` pour les clients admin

## 🚀 Installation

### Méthode 1: Interface Web (Recommandé)
1. Ouvrir dans le navigateur: `http://votre-domaine/server/migrate_clients_admin.php`
2. Vérifier que la migration s'exécute avec succès
3. ✅ Terminé !

### Méthode 2: Ligne de commande MySQL
```bash
mysql -u votre_user -p votre_database < database/alter_clients_allow_null_shop.sql
```

## 📊 Changements dans la base de données

### Avant
```sql
shop_id INT NOT NULL
```

### Après
```sql
shop_id INT NULL COMMENT 'ID du shop de création (NULL pour clients admin globaux)'
```

## 💡 Utilisation

### Pour un Agent
- Créer un client → `shop_id` est **obligatoire** (ID du shop de l'agent)
- Le client est associé à son shop

### Pour un Admin
- Créer un client → `shop_id` peut être **NULL**
- Le client est **global** et accessible depuis tous les shops
- Ou peut spécifier un `shop_id` pour associer le client à un shop spécifique

## 🔍 Vérification

Après la migration, vérifier la structure de la table :

```sql
DESCRIBE clients;
```

La colonne `shop_id` doit afficher `NULL: YES`.

## ⚠️ Important

- Cette modification est **rétrocompatible**
- Les clients existants ne sont **PAS** affectés
- Les foreign keys restent actives (la contrainte est préservée)
- Les agents doivent toujours spécifier un `shop_id` valide

## 📝 Logs de synchronisation

Après la migration, lors de la création d'un client admin, vous verrez :

```
ℹ️ Client DIDIER: shop_designation sera résolu côté serveur (shopId: null)
📤 clients: 16 enregistrement(s) non synchronisé(s) trouvé(s)
✅ clients: 1 insérés, 15 mis à jour
```

## 🎯 Avantages

1. ✅ Clients globaux accessibles depuis tous les shops
2. ✅ Flexibilité pour l'admin
3. ✅ Pas de shop par défaut "fictif" (shop_id = 1)
4. ✅ Meilleure traçabilité et gestion des clients
5. ✅ Conformité avec la logique métier

---

**Date de création**: 28 novembre 2024  
**Version UCASH**: v0.2.18  
**Statut**: ✅ Production Ready
