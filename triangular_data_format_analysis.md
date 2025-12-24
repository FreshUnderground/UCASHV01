# ANALYSE DE CONFORMITÉ DES DONNÉES TRIANGULAIRES

## 🔍 PROBLÈME IDENTIFIÉ: INCOHÉRENCE DE FORMATAGE `is_deleted`

### **ERREUR CRITIQUE DÉTECTÉE**

**Dans le modèle Flutter** (`@lib/models/triangular_debt_settlement_model.dart:108`):
```dart
isDeleted: json['is_deleted'] as bool? ?? false,  // ❌ ATTEND UN BOOL
```

**Dans la sérialisation JSON** (`@lib/models/triangular_debt_settlement_model.dart:138`):
```dart
'is_deleted': isDeleted ? 1 : 0,  // ✅ ENVOIE UN INT
```

**Dans la désérialisation** (`@lib/models/triangular_debt_settlement_model.dart:104`):
```dart
isSynced: (json['is_synced'] as int?) == 1,  // ✅ CORRECT POUR is_synced
```

### **INCOHÉRENCE DÉTECTÉE**

- `is_synced`: Correctement géré (int → bool)
- `is_deleted`: **INCORRECTEMENT géré** (attend bool mais reçoit int)

## 📊 COMPARAISON FORMATS

### **FORMAT FLUTTER → SERVEUR (toJson)**
```json
{
  "id": 1,
  "reference": "TRI20251221-83194",
  "shop_debtor_id": 1765124856371,
  "shop_debtor_designation": "shop kampala",
  "shop_intermediary_id": 1765485299073,
  "shop_intermediary_designation": "SHOP BUTEMBO",
  "shop_creditor_id": 1765124945851,
  "shop_creditor_designation": "shop kisangani",
  "montant": 7000.0,
  "devise": "USD",
  "date_reglement": "2025-12-21T07:36:23.194",
  "mode_paiement": null,
  "notes": null,
  "agent_id": 0,
  "agent_username": "admin",
  "created_at": "2025-12-21T07:36:23.194",
  "last_modified_at": "2025-12-21T07:36:23.194",
  "last_modified_by": "agent_0",
  "is_synced": 0,        // ✅ INT (0/1)
  "synced_at": "2025-12-21T07:36:42.548",
  "is_deleted": 0,       // ✅ INT (0/1)
  "deleted_at": null,
  "deleted_by": null,
  "delete_reason": null
}
```

### **FORMAT SERVEUR → FLUTTER (changes.php)**
```json
{
  "id": 1,
  "reference": "TRI20251221-83194",
  "shopDebtorId": 1765124856371,
  "shopDebtorDesignation": "shop kampala",
  "shopIntermediaryId": 1765485299073,
  "shopIntermediaryDesignation": "SHOP BUTEMBO",
  "shopCreditorId": 1765124945851,
  "shopCreditorDesignation": "shop kisangani",
  "montant": 7000.0,
  "devise": "USD",
  "dateReglement": "2025-12-21T07:36:23.194",
  "modePaiement": null,
  "notes": null,
  "agentId": 0,
  "agentUsername": "admin",
  "createdAt": "2025-12-21T07:36:23.194",
  "lastModifiedAt": "2025-12-21T07:36:23.194",
  "lastModifiedBy": "agent_0",
  "isSynced": false,     // ✅ BOOL (true/false)
  "syncedAt": "2025-12-21T07:36:42.548",
  "isDeleted": false,    // ✅ BOOL (true/false)
  "deletedAt": null,
  "deletedBy": null,
  "deleteReason": null
}
```

## ⚠️ PROBLÈMES DE CONFORMITÉ

### **1. NOMMAGE DES CHAMPS**
- **Flutter → Serveur**: `snake_case` (correct)
- **Serveur → Flutter**: `camelCase` (correct)
- **Conversion**: Gérée par `changes.php` ✅

### **2. TYPES DE DONNÉES**
- **Dates**: ISO8601 strings ✅
- **Nombres**: Correct ✅
- **Booléens**: **PROBLÈME DÉTECTÉ** ❌

### **3. CHAMPS OBLIGATOIRES**
Tous les champs requis sont présents ✅

## 🚨 IMPACT SUR LA SYNCHRONISATION

Cette incohérence peut causer:
1. **Erreurs de parsing** lors du download depuis le serveur
2. **Données corrompues** en LocalDB
3. **Échec de synchronisation** silencieux
4. **Règlements marqués comme supprimés** à tort

## 🔧 SOLUTION REQUISE

Corriger la désérialisation `is_deleted` dans le modèle Flutter:

```dart
// AVANT (incorrect)
isDeleted: json['is_deleted'] as bool? ?? false,

// APRÈS (correct)
isDeleted: (json['is_deleted'] as int?) == 1,
```
