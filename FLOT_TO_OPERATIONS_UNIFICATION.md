# 🔄 Unification FLOT → OPERATIONS

## 📋 Résumé de la Modification

Au lieu de maintenir une table `flots` séparée, nous utilisons maintenant la table `operations` existante avec un nouveau type `flotShopToShop`.

### ✅ Avantages

1. **Synchronisation unifiée** - Utilise le mécanisme de sync éprouvé des operations
2. **Code simplifié** - Un seul système d'upload/download au lieu de deux
3. **Statuts alignés** - `enAttente` → `validee` → `terminee` (comme les autres opérations)
4. **Commission = 0** - Les FLOTs ont `montantBrut = montantNet` (pas de commission)

---

## 🔧 Modifications Effectuées

### 1. **Model Flutter** (`operation_model.dart`)

```dart
enum OperationType {
  transfertNational,           // 0
  transfertInternationalSortant, // 1
  transfertInternationalEntrant, // 2
  depot,                       // 3
  retrait,                     // 4
  virement,                    // 5
  retraitMobileMoney,          // 6
  flotShopToShop,              // 7 ← NOUVEAU
}
```

**Parsing String → Enum:**
```dart
case 'flotshoptoshop':
case 'flot_shop_to_shop':
  return OperationType.flotShopToShop;
```

### 2. **API PHP** (`server/api/sync/operations/upload.php`)

```php
function _convertOperationType($index) {
    // Index 7 = flotShopToShop
    $types = [
        'transfertNational',              // 0
        'transfertInternationalSortant',  // 1
        'transfertInternationalEntrant',  // 2
        'depot',                          // 3
        'retrait',                        // 4
        'virement',                       // 5
        'retraitMobileMoney',             // 6
        'flotShopToShop'                  // 7 ← NOUVEAU
    ];
    return $types[$index] ?? 'depot';
}
```

### 3. **Base de données MySQL**

**Migration SQL:**
```sql
ALTER TABLE operations 
MODIFY COLUMN type ENUM(
    'transfertNational', 
    'transfertInternationalSortant', 
    'transfertInternationalEntrant', 
    'depot', 
    'retrait', 
    'virement', 
    'retraitMobileMoney',
    'flotShopToShop'  -- ← NOUVEAU
) NOT NULL;
```

**Fichier:** `server/database/migrations/add_flot_shop_to_shop_type.sql`

---

## 📝 Comment Créer un FLOT maintenant

### Ancienne méthode (table `flots`)
```dart
final flot = FlotModel(
  shopSourceId: 1,
  shopDestinationId: 2,
  montant: 1000,
  statut: StatutFlot.enRoute,  // ← Ancien statut
  modePaiement: ModePaiement.cash,
);
```

### **Nouvelle méthode (table `operations`)**
```dart
final flot = OperationModel(
  type: OperationType.flotShopToShop,  // ← Type spécifique FLOT
  shopSourceId: 1,
  shopSourceDesignation: 'Shop A',
  shopDestinationId: 2,
  shopDestinationDesignation: 'Shop B',
  
  // Montants (commission = 0)
  montantBrut: 1000.00,
  montantNet: 1000.00,
  commission: 0.00,  // ← TOUJOURS 0 pour les FLOTs
  
  // Statut aligné avec les operations
  statut: OperationStatus.enAttente,  // Au lieu de 'enRoute'
  
  // Agents
  agentId: 1,
  agentUsername: 'admin',
  
  // Code unique
  codeOps: 'FLOT20251127_1234',
  
  modePaiement: ModePaiement.cash,
  devise: 'USD',
  dateOp: DateTime.now(),
);
```

---

## 🔄 Correspondance des Statuts

| Ancien (StatutFlot) | Nouveau (OperationStatus) | Description |
|---------------------|---------------------------|-------------|
| `enRoute` | `enAttente` | FLOT envoyé, en transit |
| `servi` | `validee` ou `terminee` | FLOT reçu par le shop destination |
| `annule` | `annulee` | FLOT annulé |

---

## 🎯 Logique Métier

### **Création du FLOT** (Shop A envoie à Shop B)

```dart
// 1. Créer l'opération avec type flotShopToShop
final flot = OperationModel(
  type: OperationType.flotShopToShop,
  statut: OperationStatus.enAttente,  // ← En attente de réception
  montantBrut: 1000,
  montantNet: 1000,
  commission: 0,  // ← Pas de commission pour les FLOTs
  // ...
);

// 2. Impact capital Shop A (source) - SORTIE immédiate
shopA.capitalCash -= montant;

// 3. Sauvegarder l'opération
await OperationService.createOperation(flot);

// 4. Synchronisation automatique via sync_service.dart
```

### **Réception du FLOT** (Shop B reçoit)

```dart
// 1. Marquer comme validée/terminée
flot = flot.copyWith(
  statut: OperationStatus.validee,  // ou terminee
  dateValidation: DateTime.now(),
);

// 2. Impact capital Shop B (destination) - ENTRÉE
shopB.capitalCash += montant;

// 3. Mise à jour automatique via sync
```

---

## 📊 Impact sur les Rapports

### **Filtrage dans les Reports**

```dart
// Exclure les FLOTs des rapports clients
final operationsClients = operations.where(
  (op) => op.type != OperationType.flotShopToShop
).toList();

// Récupérer uniquement les FLOTs
final flots = operations.where(
  (op) => op.type == OperationType.flotShopToShop
).toList();
```

### **Calcul du Capital**

```dart
// Les FLOTs sont exclus du calcul des commissions
final totalCommissions = operations
    .where((op) => op.type != OperationType.flotShopToShop)
    .fold(0.0, (sum, op) => sum + op.commission);
```

---

## ✅ Checklist de Déploiement

### **Base de Données**
- [ ] Exécuter `add_flot_shop_to_shop_type.sql` sur le serveur MySQL
- [ ] Vérifier que le type ENUM inclut `flotShopToShop`
- [ ] Optionnel: Migrer les données existantes de `flots` vers `operations`

### **Backend PHP**
- [x] Mise à jour `upload.php` - Conversion enum index 7
- [x] Mise à jour `changes.php` - Retourne `flotShopToShop`

### **Frontend Flutter**
- [x] Mise à jour `operation_model.dart` - Ajout enum `flotShopToShop`
- [ ] Mise à jour `flot_service.dart` - Utiliser `OperationModel` au lieu de `FlotModel`
- [ ] Mise à jour UI - Labels et icônes pour `flotShopToShop`
- [ ] Mise à jour rapports - Filtrer `flotShopToShop`

### **Tests**
- [ ] Tester création FLOT avec nouveau type
- [ ] Vérifier synchronisation upload/download
- [ ] Valider impact capital correct
- [ ] Tester filtrage dans les rapports

---

## 🚨 Points d'Attention

### **1. Commission TOUJOURS = 0**
```dart
// CORRECT
OperationModel(
  type: OperationType.flotShopToShop,
  montantBrut: 1000,
  montantNet: 1000,
  commission: 0,  // ✅
)

// INCORRECT
OperationModel(
  type: OperationType.flotShopToShop,
  montantBrut: 1050,
  montantNet: 1000,
  commission: 50,  // ❌ Les FLOTs ne génèrent pas de commission
)
```

### **2. Impact Capital Inversé**

**Operations normales (Transfert client):**
- Shop A (source) reçoit montantBrut du client → `+` capital
- Shop B (destination) sert montantNet au bénéficiaire → `-` capital

**FLOT (flotShopToShop):**
- Shop A (source) donne liquidité → `-` capital
- Shop B (destination) reçoit liquidité → `+` capital

### **3. Client_id = NULL pour les FLOTs**
Les FLOTs ne sont PAS des transactions client, donc:
```dart
OperationModel(
  type: OperationType.flotShopToShop,
  clientId: null,  // ✅ Pas de client
  clientNom: null,
  destinataire: 'Shop B',  // Nom du shop destination
)
```

---

## 📖 Documentation Technique

### **Enum Index Mapping**

| Index | Type (Dart) | Type (MySQL) |
|-------|-------------|--------------|
| 0 | `transfertNational` | `'transfertNational'` |
| 1 | `transfertInternationalSortant` | `'transfertInternationalSortant'` |
| 2 | `transfertInternationalEntrant` | `'transfertInternationalEntrant'` |
| 3 | `depot` | `'depot'` |
| 4 | `retrait` | `'retrait'` |
| 5 | `virement` | `'virement'` |
| 6 | `retraitMobileMoney` | `'retraitMobileMoney'` |
| **7** | **`flotShopToShop`** | **`'flotShopToShop'`** |

**CRITIQUE:** Ne JAMAIS modifier l'ordre de cet enum sans mettre à jour les 3 endroits:
1. `lib/models/operation_model.dart`
2. `server/api/sync/operations/upload.php` → `_convertOperationType()`
3. `database/migrations/*.sql` → ALTER TABLE type ENUM

---

## 🔗 Fichiers Modifiés

1. `lib/models/operation_model.dart` - Ajout enum `flotShopToShop`
2. `server/api/sync/operations/upload.php` - Conversion index 7
3. `server/database/migrations/add_flot_shop_to_shop_type.sql` - Migration SQL

---

## 📞 Support

Si des problèmes surviennent après la migration:
- Vérifier que l'index enum correspond (7 = flotShopToShop)
- Vérifier que la migration SQL a été exécutée
- Checker les logs PHP pour les erreurs de conversion

**Date:** 27 Novembre 2025  
**Version:** 1.0  
**Auteur:** UCASH Development Team
