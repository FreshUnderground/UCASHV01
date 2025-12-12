# 📋 Logique Administrative - Documentation Complète

## 🎯 Vue d'Ensemble

La **logique administrative** permet de créer des opérations et transactions virtuelles qui **n'impactent PAS le cash disponible** mais créent des dettes/crédits entre shops et permettent d'attribuer des frais.

### Applications

| Type | Usage | Impacte Cash? | Crée Dettes? | Synchronisé? |
|------|-------|---------------|--------------|--------------|
| **Flots Administratifs** | Régularisation dettes inter-shops | ❌ Non | ✅ Oui | ✅ Oui |
| **Transactions Virtuelles Administratives** | Ajustements soldes virtuels | ❌ Non | ❌ Non | ✅ Oui |

---

## 🏗️ Architecture Technique

### 1️⃣ Opérations (Flots Administratifs)

#### Modèle Flutter
```dart
class OperationModel {
  final bool isAdministrative; // Default: false
  // ... autres champs
}
```

#### Base de Données
```sql
ALTER TABLE operations 
ADD COLUMN is_administrative BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_operations_is_administrative 
ON operations(is_administrative);
```

#### Exclusion du Cash Disponible
```dart
// Dans rapport_cloture_service.dart
final flotsRecusServis = operations.where((f) =>
    f.type == OperationType.flotShopToShop &&
    f.shopDestinationId == shopId &&
    f.statut == OperationStatus.validee &&
    f.isAdministrative == false && // ← EXCLUSION
    _isSameDay(f.dateValidation ?? f.createdAt ?? f.dateOp, dateRapport)
).toList();
```

#### Inclusion dans les Dettes
```dart
// TOUS les flots (administratifs inclus)
final allFlots = operations.where((op) => 
    op.type == OperationType.flotShopToShop
).toList();
```

---

### 2️⃣ Transactions Virtuelles Administratives

#### Modèle Flutter
```dart
class VirtualTransactionModel {
  final bool isAdministrative; // Default: false
  // ... autres champs
}
```

#### Base de Données
```sql
ALTER TABLE virtual_transactions 
ADD COLUMN is_administrative BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_virtual_transactions_is_administrative 
ON virtual_transactions(is_administrative);
```

#### Exclusion du Cash dans Clôture Virtuelle
```dart
// Dans cloture_virtuelle_service.dart
for (var trans in allTransactions) {
  final isNormalTransaction = !trans.isAdministrative;
  
  montantTotalCaptures += trans.montantVirtuel;
  
  if (isNormalTransaction) {
    cashSortiCaptures += trans.montantVirtuel; // Seulement si normal
  }
  
  if (trans.statut == VirtualTransactionStatus.validee) {
    if (isNormalTransaction) {
      cashServi += trans.montantCash; // Seulement si normal
    }
  }
}
```

---

## 🚀 Déploiement

### Script Automatique

```bash
deploy_administrative_logic_complete.bat
```

Ce script :
1. ✅ Vérifie les fichiers de migration
2. ✅ Exécute les migrations SQL (operations + virtual_transactions)
3. ✅ Copie les fichiers PHP mis à jour
4. ✅ Teste la migration

### Déploiement Manuel

#### Étape 1 : Migrations SQL

```bash
# Operations
mysql -u root ucash_db < database/add_is_administrative_to_operations.sql

# Virtual Transactions
mysql -u root ucash_db < database/add_is_administrative_to_virtual_transactions.sql
```

#### Étape 2 : Vérification

```sql
-- Vérifier operations
SHOW COLUMNS FROM operations LIKE 'is_administrative';

-- Vérifier virtual_transactions
SHOW COLUMNS FROM virtual_transactions LIKE 'is_administrative';
```

---

## 📊 Cas d'Usage

### Exemple 1 : Flot Administratif (Régularisation Inter-Shops)

**Situation** :
- Shop B doit 1000 USD à Shop A (transferts servis en novembre)
- L'admin veut régulariser sans mouvement de cash

**Action** :
```
Menu Admin → Dashboard → Flot Administratif

Shop Source: Shop B (débiteur)
Shop Destination: Shop A (créancier)
Date: 20/11/2025
Montant: 1000 USD
Frais Shop A: 50 USD (compensation)
Notes: "Régularisation transferts novembre"
```

**Résultats** :
```
✅ Dettes Intershop:
   - Shop B doit 1000 USD à Shop A

✅ Compte FRAIS Shop A:
   - +50 USD (frais attribués)

❌ Cash Disponible:
   - Shop A: INCHANGÉ
   - Shop B: INCHANGÉ

✅ Synchronisation:
   - Flot visible sur tous les appareils
```

---

### Exemple 2 : Transaction Virtuelle Administrative (Ajustement Solde)

**Situation** :
- Erreur de saisie : Transaction virtuelle créée par erreur
- L'admin veut créer une contre-transaction sans impacter le cash

**Action** :
```
Menu Virtuel → Créer Transaction

Référence: ADM-CORR-001
Montant Virtuel: -500 USD (correction)
SIM: 0812345678
Statut: Validée
is_administrative: TRUE
Notes: "Correction erreur saisie"
```

**Résultats** :
```
✅ Solde Virtuel SIM:
   - Ajusté de -500 USD

❌ Cash Disponible:
   - INCHANGÉ (pas d'impact cash)

✅ Rapport Clôture Virtuelle:
   - Transaction visible mais exclue du cash
```

---

## 🔍 Vérifications SQL

### 1. Vérifier les Flots Administratifs

```sql
SELECT 
    id, code_ops,
    shop_source_designation,
    shop_destination_designation,
    montant_net,
    is_administrative,
    notes
FROM operations 
WHERE is_administrative = 1
AND type = 'flotShopToShop'
ORDER BY created_at DESC
LIMIT 10;
```

### 2. Vérifier les Transactions Virtuelles Administratives

```sql
SELECT 
    id, reference,
    montant_virtuel,
    montant_cash,
    sim_numero,
    shop_designation,
    is_administrative,
    notes
FROM virtual_transactions 
WHERE is_administrative = 1
ORDER BY date_enregistrement DESC
LIMIT 10;
```

### 3. Statistiques Globales

```sql
-- Operations
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN is_administrative = 1 THEN 1 ELSE 0 END) as administratives,
    SUM(CASE WHEN is_administrative = 0 THEN 1 ELSE 0 END) as normales
FROM operations;

-- Virtual Transactions
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN is_administrative = 1 THEN 1 ELSE 0 END) as administratives,
    SUM(CASE WHEN is_administrative = 0 THEN 1 ELSE 0 END) as normales
FROM virtual_transactions;
```

---

## 📝 Fichiers Modifiés

### Flutter (lib/)

| Fichier | Modification |
|---------|--------------|
| `models/operation_model.dart` | Ajout `isAdministrative: bool` |
| `models/virtual_transaction_model.dart` | Ajout `isAdministrative: bool` |
| `widgets/admin_flot_dialog.dart` | Dialog création + date picker |
| `services/rapport_cloture_service.dart` | Exclusion flots admin + frais manuels |
| `services/cloture_virtuelle_service.dart` | Exclusion transactions admin du cash |
| `pages/dashboard_admin.dart` | Bouton "Flot Administratif" |

### Serveur (server/)

| Fichier | Modification |
|---------|--------------|
| `api/sync/operations/upload.php` | INSERT/UPDATE `is_administrative` |
| `api/sync/operations/changes.php` | SELECT + JSON `is_administrative` |
| `api/sync/virtual_transactions/changes.php` | SELECT + JSON `is_administrative` |
| `classes/SyncManager.php` | INSERT/UPDATE virtual trans `is_administrative` |

### Base de Données

| Table | Colonne |
|-------|---------|
| `operations` | `is_administrative BOOLEAN DEFAULT FALSE` |
| `virtual_transactions` | `is_administrative BOOLEAN DEFAULT FALSE` |

---

## 🐛 Troubleshooting

### Problème 1 : Flot administratif impacte le cash

**Cause** : Migration SQL non exécutée ou filtre manquant  
**Solution** :
```sql
-- Vérifier la colonne
SHOW COLUMNS FROM operations LIKE 'is_administrative';

-- Si manquante, exécuter
mysql -u root ucash_db < database/add_is_administrative_to_operations.sql
```

### Problème 2 : Transaction virtuelle administrative impacte le cash

**Cause** : Migration SQL ou code Flutter manquant  
**Solution** :
```sql
-- Vérifier la colonne
SHOW COLUMNS FROM virtual_transactions LIKE 'is_administrative';

-- Vérifier le code
grep -n "isNormalTransaction" lib/services/cloture_virtuelle_service.dart
```

### Problème 3 : Synchronisation échoue

**Cause** : Serveur PHP ne supporte pas le champ  
**Solution** :
```bash
# Redéployer les fichiers PHP
deploy_administrative_logic_complete.bat

# Vérifier les logs
tail -f C:\laragon\bin\apache\logs\error.log | grep "is_administrative"
```

---

## ✅ Checklist de Validation

- [ ] Migration SQL operations exécutée
- [ ] Migration SQL virtual_transactions exécutée
- [ ] Fichiers PHP déployés
- [ ] Application Flutter redémarrée
- [ ] Test création flot administratif
- [ ] Vérification dettes inter-shops (flot visible)
- [ ] Vérification cash disponible (inchangé)
- [ ] Test transaction virtuelle administrative
- [ ] Vérification clôture virtuelle (cash exclu)
- [ ] Synchronisation multi-appareils testée

---

## 📚 Références

- [ADMIN_FLOTS_ADMINISTRATIFS.md](ADMIN_FLOTS_ADMINISTRATIFS.md) - Documentation flots
- [VIRTUAL_CLOSURE_GUIDE.md](VIRTUAL_CLOSURE_GUIDE.md) - Clôture virtuelle
- [SYNC_README.md](SYNC_README.md) - Synchronisation générale

---

**✨ La logique administrative est maintenant complète pour les opérations et les transactions virtuelles!**
