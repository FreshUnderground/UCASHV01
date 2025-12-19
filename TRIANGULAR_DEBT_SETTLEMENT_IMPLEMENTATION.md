# Règlement Triangulaire de Dettes Inter-Shops

## 📋 Vue d'ensemble

**Scénario**: Shop A doit à Shop C, mais c'est Shop B qui reçoit l'agent de Shop A pour le compte de Shop C.

**Impacts sur les dettes**:
- ✅ Dette de Shop A envers Shop C: **diminue**
- ✅ Dette de Shop B envers Shop C: **augmente**

## 🎯 Exemple Concret

### Situation Initiale
- Shop MOKU doit 5000 USD à Shop NGANGAZU
- Shop BUKAVU doit 0 USD à Shop NGANGAZU

### Transaction
- Agent de MOKU paie 5000 USD à Shop BUKAVU pour le compte de NGANGAZU

### Résultat Final
- Shop MOKU doit maintenant **0 USD** à NGANGAZU (dette diminuée de 5000 USD)
- Shop BUKAVU doit maintenant **5000 USD** à NGANGAZU (dette augmentée de 5000 USD)
- Shop NGANGAZU: créances totales **inchangées** (transfert de dette de MOKU à BUKAVU)

## 🏗️ Architecture Technique

### Composants Créés

#### 1. **Modèle de Données**
**Fichier**: `lib/models/triangular_debt_settlement_model.dart`

```dart
class TriangularDebtSettlementModel {
  // Shops impliqués
  final int shopDebtorId;         // Shop A (débiteur)
  final int shopIntermediaryId;   // Shop B (intermédiaire)
  final int shopCreditorId;       // Shop C (créancier)
  
  // Informations du règlement
  final double montant;
  final String devise;
  final DateTime dateReglement;
  final String? modePaiement;
  final String? notes;
}
```

**Caractéristiques**:
- Références aux 3 shops impliqués
- Génération automatique de référence unique (format: `TRI20241218-XXXXX`)
- Support de synchronisation avec le serveur
- Métadonnées de traçabilité (agent, dates)

#### 2. **Schéma Base de Données**
**Fichier**: `database/create_triangular_debt_settlement_table.sql`

```sql
CREATE TABLE triangular_debt_settlements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(50) NOT NULL UNIQUE,
    shop_debtor_id INT NOT NULL,
    shop_intermediary_id INT NOT NULL,
    shop_creditor_id INT NOT NULL,
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) DEFAULT 'USD',
    date_reglement DATETIME NOT NULL,
    -- ... autres champs
    CONSTRAINT chk_different_shops CHECK (
        shop_debtor_id != shop_intermediary_id AND
        shop_debtor_id != shop_creditor_id AND
        shop_intermediary_id != shop_creditor_id
    )
);
```

**Contraintes**:
- Les 3 shops DOIVENT être différents
- Le montant DOIT être positif
- Référence unique par règlement

#### 3. **Service Métier**
**Fichier**: `lib/services/triangular_debt_settlement_service.dart`

**Méthode principale**: `createTriangularSettlement()`

```dart
Future<TriangularDebtSettlementModel> createTriangularSettlement({
  required int shopDebtorId,
  required int shopIntermediaryId,
  required int shopCreditorId,
  required double montant,
  required int agentId,
  String? notes,
}) async {
  // 1. Validation des 3 shops différents
  // 2. Création du règlement
  // 3. Mise à jour automatique des dettes
  //    - Shop A: dettes -= montant
  //    - Shop B: dettes += montant
  //    - Shop C: créances inchangées
}
```

**Logique de Mise à Jour**:
```dart
// Shop A (débiteur): Sa dette envers C diminue
updatedShopDebtor.dettes -= montant;

// Shop B (intermédiaire): Sa dette envers C augmente  
updatedShopIntermediary.dettes += montant;

// Shop C (créancier): Créances globalement constantes
// (dette transférée de A vers B)
```

#### 4. **Méthodes LocalDB**
**Fichier**: `lib/services/local_db.dart`

Méthodes ajoutées:
- ✅ `saveTriangularDebtSettlement(settlement)`
- ✅ `updateTriangularDebtSettlement(settlement)`
- ✅ `getAllTriangularDebtSettlements({shopId, dateDebut, dateFin})`
- ✅ `getTriangularDebtSettlementById(id)`
- ✅ `getTriangularDebtSettlementByReference(reference)`
- ✅ `deleteTriangularDebtSettlement(id)`

#### 5. **Interface Utilisateur**
**Fichier**: `lib/widgets/admin_initialization_widget.dart`

**Nouvel Onglet**: "🔺 Règlement Triangulaire"

**Formulaire**:
- 🏪 Shop A - Débiteur (qui doit l'argent)
- 🏪 Shop B - Intermédiaire (qui reçoit le paiement)
- 🏪 Shop C - Créancier (à qui l'argent est dû)
- 💰 Montant (USD)
- 📝 Notes / Observation

**Validation**:
- Les 3 shops doivent être sélectionnés
- Les 3 shops doivent être DIFFÉRENTS
- Le montant doit être positif

**Affichage des Impacts**:
```
✅ Dette de Shop A envers Shop C: diminue de X USD
❌ Dette de Shop B envers Shop C: augmente de X USD
ℹ️ Créances de Shop C: inchangées (transfert de dette)
```

## 📊 Intégration dans les Rapports

### Rapport Dettes Intershop
Le rapport existant peut être étendu pour inclure les règlements triangulaires.

**Affichage suggéré**:
```
Date       | Type               | Montant | Shops Impliqués
-----------|-------------------|---------|---------------------------
2024-12-18 | Règl. Triangulaire | 5000 USD | MOKU → BUKAVU (pour NGANGAZU)
```

## 🔐 Sécurité et Validation

### Contraintes Métier
1. **3 Shops Distincts**: Impossible de créer un règlement avec des shops identiques
2. **Montant Positif**: Le montant doit toujours être > 0
3. **Shops Existants**: Vérification de l'existence des 3 shops
4. **Permissions Admin**: Seuls les administrateurs peuvent créer des règlements triangulaires

### Traçabilité
- Chaque règlement enregistre:
  - Agent créateur
  - Date de création
  - Date de dernière modification
  - Référence unique

## 🔄 Synchronisation Server

### API Endpoints à Créer

**1. Upload Triangular Debt Settlements**
```php
POST /api/sync/triangular_settlements/upload.php
```

**2. Download Triangular Debt Settlements**
```php
GET /api/sync/triangular_settlements/download.php
```

**Structure JSON**:
```json
{
  "settlements": [
    {
      "id": 1,
      "reference": "TRI20241218-12345",
      "shop_debtor_id": 1,
      "shop_debtor_designation": "MOKU",
      "shop_intermediary_id": 2,
      "shop_intermediary_designation": "BUKAVU",
      "shop_creditor_id": 3,
      "shop_creditor_designation": "NGANGAZU",
      "montant": 5000.00,
      "devise": "USD",
      "date_reglement": "2024-12-18T10:30:00Z",
      "notes": "Paiement pour le compte de NGANGAZU",
      "agent_id": 5,
      "agent_username": "admin",
      "is_synced": 1
    }
  ]
}
```

## 📝 Utilisation

### Admin: Créer un Règlement Triangulaire

1. **Navigation**: Admin → Initialisation Système → Onglet "Règlement Triangulaire"

2. **Saisie**:
   - Sélectionner Shop A (débiteur)
   - Sélectionner Shop B (intermédiaire)
   - Sélectionner Shop C (créancier)
   - Entrer le montant
   - Ajouter des notes (optionnel)

3. **Validation**: Le système affiche un récapitulatif des impacts

4. **Création**: Cliquer sur "Créer Règlement Triangulaire"

5. **Résultat**: 
   - Règlement créé avec référence unique
   - Dettes des shops mises à jour automatiquement
   - Message de confirmation affiché

### Agent: Créer un Règlement Triangulaire (RESTREINT À SON SHOP)

**🔒 Règle Métier**: Les agents peuvent créer des règlements triangulaires UNIQUEMENT impliquant leur propre shop.

Le shop de l'agent DOIT être soit:
1. **Le Débiteur (Shop A)**: Le shop de l'agent doit de l'argent et paie via un intermédiaire
2. **L'Intermédiaire (Shop B)**: Le shop de l'agent reçoit un paiement pour le compte d'un créancier

#### Scénario 1: Mon Shop Paie (Débiteur)
**Exemple**: Agent du Shop MOKU
- MOKU (mon shop) doit 5000 USD à NGANGAZU
- Je paie 5000 USD à BUKAVU pour le compte de NGANGAZU
- **Résultat**:
  - Dette de MOKU envers NGANGAZU: diminue de 5000 USD ✅
  - Dette de BUKAVU envers NGANGAZU: augmente de 5000 USD ❌

**Champs du formulaire**:
- 🏪 Shop Intermédiaire (qui reçoit le paiement)
- 🏦 Shop Créancier (à qui on doit)
- 💵 Montant en USD

#### Scénario 2: Mon Shop Reçoit (Intermédiaire)
**Exemple**: Agent du Shop BUKAVU
- Shop MOKU doit 5000 USD à NGANGAZU
- MOKU paie 5000 USD à BUKAVU (mon shop) pour le compte de NGANGAZU
- **Résultat**:
  - Dette de MOKU envers NGANGAZU: diminue de 5000 USD ✅
  - Dette de BUKAVU (mon shop) envers NGANGAZU: augmente de 5000 USD ❌

**Champs du formulaire**:
- 🏪 Shop Débiteur (qui paie)
- 🏦 Shop Créancier (pour qui on reçoit)
- 💵 Montant en USD

#### Navigation Agent
**Chemin**: Agent Dashboard → Menu "Règl. Triangulaire"

**Caractéristiques**:
- ✅ Affichage du shop de l'agent en évidence
- ✅ Boutons radio pour choisir le rôle (Débiteur ou Intermédiaire)
- ✅ Champs dynamiques selon le rôle sélectionné
- ✅ Aperçu en temps réel avec mention "VOTRE SHOP"
- ✅ Validation garantissant 3 shops différents
- ✅ Mise à jour automatique des dettes

#### Contraintes de Sécurité
1. L'agent DOIT être connecté
2. Le shop ID de l'agent DOIT être disponible
3. Le shop de l'agent DOIT être impliqué (débiteur OU intermédiaire)
4. Les 3 shops DOIVENT être différents
5. Le montant DOIT être positif

#### Fichier Créé
**Widget**: `lib/widgets/agent_triangular_debt_settlement_widget.dart`
- 588 lignes de code
- Validation complète et gestion d'erreurs
- Design responsive (mobile & desktop)
- Intégré avec les services existants

---

## 🔐 Comparaison Admin vs Agent

| Fonctionnalité | Admin | Agent |
|---------|-------|-------|
| **Méthode d'accès** | Onglet Initialisation | Menu dédié |
| **Sélection shops** | 3 shops quelconques | Doit inclure leur shop |
| **Flexibilité rôle** | Complète (A, B ou C) | Limitée (A ou B uniquement) |
| **Emplacement UI** | Dashboard Admin | Dashboard Agent |
| **Permissions** | Sans restriction | Restreint au shop |
| **Cas d'usage** | Initialisation globale | Opérations quotidiennes |

---

## 📝 Utilisation

1. **Navigation**: Admin → Initialisation Système → Onglet "Règlement Triangulaire"

2. **Saisie**:
   - Sélectionner Shop A (débiteur)
   - Sélectionner Shop B (intermédiaire)
   - Sélectionner Shop C (créancier)
   - Entrer le montant
   - Ajouter des notes (optionnel)

3. **Validation**: Le système affiche un récapitulatif des impacts

4. **Création**: Cliquer sur "Créer Règlement Triangulaire"

5. **Résultat**: 
   - Règlement créé avec référence unique
   - Dettes des shops mises à jour automatiquement
   - Message de confirmation affiché

### Consulter les Règlements

```dart
// Tous les règlements
final allSettlements = await TriangularDebtSettlementService.instance.getAllSettlements();

// Règlements d'un shop spécifique
final shopSettlements = await TriangularDebtSettlementService.instance.getSettlementsByShop(shopId);

// Règlements dans une période
final periodSettlements = await TriangularDebtSettlementService.instance.getSettlementsByDateRange(
  startDate: DateTime(2024, 12, 1),
  endDate: DateTime(2024, 12, 31),
);
```

## ⚠️ Points d'Attention

1. **Annulation**: Supprimer un règlement inverse automatiquement les impacts sur les dettes
2. **Synchronisation**: Les règlements doivent être synchronisés avec le serveur
3. **Historique**: Tous les règlements sont conservés pour audit
4. **Permissions**: Seuls les admins ont accès à cette fonctionnalité

## 🚀 Prochaines Étapes

- [ ] Créer les endpoints API de synchronisation
- [ ] Intégrer dans le rapport Dettes Intershop
- [ ] Ajouter des tests unitaires
- [ ] Documenter les cas d'usage métier
- [ ] Former les utilisateurs finaux

## 📄 Fichiers Modifiés/Créés

### Nouveaux Fichiers
1. `lib/models/triangular_debt_settlement_model.dart` - Modèle de données
2. `lib/services/triangular_debt_settlement_service.dart` - Logique métier
3. `database/create_triangular_debt_settlement_table.sql` - Schéma BDD

### Fichiers Modifiés
1. `lib/services/local_db.dart` - Ajout méthodes CRUD
2. `lib/widgets/admin_initialization_widget.dart` - Nouvel onglet UI (en cours)

---

**Date**: 18 Décembre 2024  
**Version**: 1.0  
**Status**: ✅ Implémentation Core Complète (UI en finalisation)
