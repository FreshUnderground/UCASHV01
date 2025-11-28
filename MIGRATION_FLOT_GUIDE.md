# 🚀 Guide de Migration: FLOT → OPERATIONS

## ✅ Résumé

Nous avons ajouté le type `flotShopToShop` dans `OperationType` pour unifier la gestion des FLOTs avec les operations normales. Cela permet d'utiliser le **même système de synchronisation** pour tous les types de transactions.

---

## 📋 Étapes de Déploiement

### **Étape 1: Base de Données (OBLIGATOIRE)**

Exécuter cette migration SQL sur votre serveur MySQL:

```bash
# Se connecter à MySQL
mysql -u root -p ucash_db

# Exécuter la migration
source server/database/migrations/add_flot_shop_to_shop_type.sql
```

Ou via phpMyAdmin:
1. Sélectionner la base `ucash_db`
2. Onglet "SQL"
3. Copier-coller le contenu de `add_flot_shop_to_shop_type.sql`
4. Exécuter

**Vérification:**
```sql
-- Doit afficher flotShopToShop dans la liste
SHOW COLUMNS FROM operations LIKE 'type';
```

---

### **Étape 2: Code Flutter (DÉJÀ FAIT ✅)**

Les modifications suivantes ont déjà été appliquées:

1. ✅ `lib/models/operation_model.dart` - Ajout enum `flotShopToShop`
2. ✅ `test/flot_shop_to_shop_enum_test.dart` - Tests unitaires (9/9 passent)

---

### **Étape 3: Backend PHP (DÉJÀ FAIT ✅)**

1. ✅ `server/api/sync/operations/upload.php` - Conversion index 7
2. ✅ Pas de modification nécessaire dans `changes.php` (retourne déjà le string MySQL)

---

## 📝 Comment Utiliser

### **Créer un FLOT via OperationModel**

```dart
import 'package:ucashv01/models/operation_model.dart';
import 'package:ucashv01/services/operation_service.dart';

// Créer un FLOT de 1000 USD de Shop A → Shop B
final flot = OperationModel(
  // Type spécifique FLOT
  type: OperationType.flotShopToShop,
  
  // Shops
  shopSourceId: 1,
  shopSourceDesignation: 'Shop A',
  shopDestinationId: 2,
  shopDestinationDesignation: 'Shop B',
  
  // Montants (IMPORTANT: commission = 0 pour les FLOTs)
  montantBrut: 1000.00,
  montantNet: 1000.00,
  commission: 0.00,  // ← TOUJOURS 0
  devise: 'USD',
  
  // Statut (utilise les statuts d'opération)
  statut: OperationStatus.enAttente,  // Au lieu de StatutFlot.enRoute
  
  // Agent
  agentId: agentId,
  agentUsername: agentUsername,
  
  // Code unique
  codeOps: 'FLOT_${DateTime.now().millisecondsSinceEpoch}',
  
  // Mode paiement
  modePaiement: ModePaiement.cash,
  
  // Destinataire (nom du shop destination)
  destinataire: 'Shop B',
  
  // Dates
  dateOp: DateTime.now(),
  createdAt: DateTime.now(),
  lastModifiedAt: DateTime.now(),
  lastModifiedBy: 'agent_$agentUsername',
);

// Sauvegarder et synchroniser
await OperationService.instance.createOperation(flot);
```

---

### **Marquer un FLOT comme Reçu**

```dart
// Récupérer le FLOT en attente
final flot = await LocalDB.instance.getOperationById(flotId);

// Marquer comme validé/terminé
final flotServi = flot.copyWith(
  statut: OperationStatus.validee,  // ou terminee
  dateValidation: DateTime.now(),
  lastModifiedAt: DateTime.now(),
);

// Mettre à jour
await OperationService.instance.updateOperation(flotServi);
```

---

### **Filtrer les FLOTs dans les Rapports**

```dart
// Récupérer uniquement les FLOTs
final flots = await LocalDB.instance.getAllOperations();
final flotsShopToShop = flots.where(
  (op) => op.type == OperationType.flotShopToShop
).toList();

// Exclure les FLOTs des opérations clients
final operationsClients = flots.where(
  (op) => op.type != OperationType.flotShopToShop
).toList();
```

---

## 🔄 Correspondance Statuts

| Ancien (FlotModel) | Nouveau (OperationModel) |
|--------------------|--------------------------|
| `StatutFlot.enRoute` | `OperationStatus.enAttente` |
| `StatutFlot.servi` | `OperationStatus.validee` ou `terminee` |
| `StatutFlot.annule` | `OperationStatus.annulee` |

---

## ⚠️ Points Importants

### **1. Commission TOUJOURS = 0**
```dart
// ✅ CORRECT
OperationModel(
  type: OperationType.flotShopToShop,
  montantBrut: 1000,
  montantNet: 1000,
  commission: 0,  // ← OBLIGATOIRE
)

// ❌ INCORRECT
OperationModel(
  type: OperationType.flotShopToShop,
  commission: 50,  // ← NE PAS FAIRE ÇA
)
```

### **2. Pas de Client pour les FLOTs**
```dart
OperationModel(
  type: OperationType.flotShopToShop,
  clientId: null,     // ← Pas de client
  clientNom: null,
  destinataire: 'Shop B',  // ← Nom du shop destination
)
```

### **3. Synchronisation Automatique**
Les FLOTs utilisent maintenant le même système de sync que les operations:
- Upload via `operations/upload.php`
- Download via `operations/changes.php`
- Même mécanisme de retry
- Même gestion des conflits

---

## 🧪 Tests

Vérifier que tout fonctionne:

```bash
# Tests unitaires (doivent tous passer)
flutter test test/flot_shop_to_shop_enum_test.dart

# Résultat attendu:
# 00:23 +9: All tests passed! ✅
```

---

## 📊 Avantages de cette Approche

| Aspect | Avant (table flots) | Après (operations) |
|--------|---------------------|---------------------|
| **Sync** | 2 systèmes séparés | 1 système unifié ✅ |
| **Code** | FlotService + SyncService | OperationService seulement ✅ |
| **Maintenance** | 2 endpoints à maintenir | 1 endpoint ✅ |
| **Statuts** | enRoute/servi/annule | Aligné avec operations ✅ |
| **Tests** | Tests séparés | Tests unifiés ✅ |

---

## 🔧 Dépannage

### **Erreur: "Unknown column 'type' value 'flotShopToShop'"**
→ La migration SQL n'a pas été exécutée. Exécuter `add_flot_shop_to_shop_type.sql`

### **Erreur: "Enum index out of range"**
→ Vérifier que Flutter et PHP utilisent le même index (7 = flotShopToShop)

### **Les FLOTs n'apparaissent pas dans les rapports**
→ Utiliser le filtre: `op.type == OperationType.flotShopToShop`

---

## 📚 Documentation Complète

Voir [`FLOT_TO_OPERATIONS_UNIFICATION.md`](./FLOT_TO_OPERATIONS_UNIFICATION.md) pour la documentation technique complète.

---

**Date:** 27 Novembre 2025  
**Version:** 1.0  
**Status:** ✅ Tests Passés (9/9)
