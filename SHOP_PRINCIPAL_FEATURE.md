# 🏢 Fonctionnalité Shop Principal

## 📋 Vue d'Ensemble

Ajout d'une nouvelle fonctionnalité permettant de distinguer le **Shop Principal** (siège/central) des **Shops Secondaires** (agences/succursales) lors de la création d'un shop.

---

## ✨ Nouveautés

### 1. **Champ `isPrincipal` dans le Modèle Shop**

```dart
class ShopModel {
  final bool isPrincipal; // true = Shop Principal, false = Shop Secondaire
}
```

### 2. **Case à Cocher dans le Formulaire**

Lors de la création d'un nouveau shop, l'administrateur peut cocher une case pour indiquer qu'il s'agit du shop principal:

- ✅ **Coché**: Shop Principal (Siège/Central)
- ⬜ **Non coché**: Shop Secondaire (Agence/Succursale) - **Par défaut**

---

## 🎨 Interface Utilisateur

### Formulaire de Création de Shop

```
┌─────────────────────────────────────────────┐
│ 🏪 Nouveau Shop                             │
├─────────────────────────────────────────────┤
│                                             │
│ Désignation *                               │
│ [Ex: UCASH Central                     ]    │
│                                             │
│ Localisation *                              │
│ [Ex: Kinshasa, Gombe                   ]    │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ☑ Shop Principal                        │ │
│ │   Cochez si ce shop est le siège/central│ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Capitaux par Type de Caisse (USD)          │
│ Capital Cash *                              │
│ [Ex: 20000                             ]    │
│                                             │
│            [Annuler]  [Créer]               │
└─────────────────────────────────────────────┘
```

### Notification de Succès

Après création, un message confirme:

- Shop normal: `"Shop créé avec succès! Capital total: 20000 USD"`
- Shop principal: `"Shop créé avec succès! (Shop Principal) Capital total: 20000 USD"`

---

## 🗄️ Base de Données

### Migration SQL

Fichier: [`database/add_is_principal_to_shops.sql`](../database/add_is_principal_to_shops.sql)

```sql
-- Ajouter la colonne is_principal
ALTER TABLE shops 
ADD COLUMN is_principal TINYINT(1) DEFAULT 0 
COMMENT 'Shop principal (siège/central): 1=Oui, 0=Non';

-- Créer un index pour optimiser les requêtes
CREATE INDEX idx_shops_is_principal ON shops(is_principal);
```

### Structure de la Colonne

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `is_principal` | `TINYINT(1)` | `0` | `1` = Shop Principal, `0` = Shop Secondaire |

---

## 💻 Code Modifié

### Fichiers Flutter (Frontend)

#### 1. **Model Shop** - [`lib/models/shop_model.dart`](../lib/models/shop_model.dart)

**Ajouts:**
```dart
// Nouveau champ
final bool isPrincipal;

// Constructeur
ShopModel({
  // ...
  this.isPrincipal = false,
  // ...
})

// Sérialisation JSON
toJson() {
  return {
    // ...
    'is_principal': isPrincipal ? 1 : 0,
    // ...
  };
}

// Désérialisation JSON
factory ShopModel.fromJson(Map<String, dynamic> json) {
  return ShopModel(
    // ...
    isPrincipal: _parseBoolSafe(json['is_principal']) ?? false,
    // ...
  );
}
```

#### 2. **Formulaire de Création** - [`lib/widgets/create_shop_dialog.dart`](../lib/widgets/create_shop_dialog.dart)

**Ajouts:**
```dart
// Variable d'état
bool _isPrincipal = false;

// Case à cocher
CheckboxListTile(
  title: const Text('Shop Principal'),
  subtitle: const Text('Cochez si ce shop est le siège/central'),
  value: _isPrincipal,
  onChanged: (bool? value) {
    setState(() {
      _isPrincipal = value ?? false;
    });
  },
)

// Appel du service
await shopService.createShop(
  // ...
  isPrincipal: _isPrincipal,
  // ...
);
```

#### 3. **Service Shop** - [`lib/services/shop_service.dart`](../lib/services/shop_service.dart)

**Ajouts:**
```dart
Future<bool> createShop({
  required String designation,
  required String localisation,
  bool isPrincipal = false, // Nouveau paramètre
  // ...
}) async {
  final newShop = ShopModel(
    // ...
    isPrincipal: isPrincipal,
    // ...
  );
}
```

---

### Fichiers PHP (Backend)

#### 1. **API Update** - [`server/api/shops/update.php`](../server/api/shops/update.php)

**Ajouts:**
```php
$allowedFields = [
    'designation',
    'localisation',
    'is_principal', // Nouveau champ
    'capital_initial',
    // ...
];
```

#### 2. **Sync Manager** - [`server/classes/SyncManager.php`](../server/classes/SyncManager.php)

**Ajouts dans `insertShop()`:**
```php
$sql = "INSERT IGNORE INTO shops (
    id,
    designation, localisation, is_principal, // Nouveau champ
    capital_initial,
    // ...
) VALUES (?, ?, ?, ?, ...)";

$result = $stmt->execute([
    $data['id'] ?? null,
    $data['designation'] ?? '',
    $data['localisation'] ?? '',
    $data['is_principal'] ?? 0, // Nouvelle valeur
    // ...
]);
```

**Ajouts dans `updateShop()`:**
```php
$sql = "UPDATE shops SET 
    designation = ?, localisation = ?, is_principal = ?, // Nouveau champ
    capital_initial = ?,
    // ...
    WHERE id = ?";

$result = $stmt->execute([
    $data['designation'] ?? '',
    $data['localisation'] ?? '',
    $data['is_principal'] ?? 0, // Nouvelle valeur
    // ...
]);
```

---

## 🚀 Utilisation

### 1. **Appliquer la Migration SQL**

```bash
# Se connecter à MySQL
mysql -u your_user -p your_database

# Exécuter le script
source database/add_is_principal_to_shops.sql;
```

### 2. **Créer un Shop Principal**

1. Connectez-vous en tant qu'administrateur
2. Allez dans **Gestion des Shops**
3. Cliquez sur **Nouveau Shop**
4. Remplissez les champs:
   - Désignation: `UCASH Central`
   - Localisation: `Kinshasa, Gombe`
   - ☑ **Cocher "Shop Principal"**
   - Capital Cash: `50000`
5. Cliquez sur **Créer**

### 3. **Créer un Shop Secondaire**

Même procédure, mais **ne pas cocher** "Shop Principal"

---

## 📊 Requêtes Utiles

### Récupérer le Shop Principal

```sql
SELECT * FROM shops WHERE is_principal = 1;
```

### Compter les Shops Secondaires

```sql
SELECT COUNT(*) FROM shops WHERE is_principal = 0;
```

### Lister tous les Shops avec leur Type

```sql
SELECT 
  id,
  designation,
  localisation,
  CASE 
    WHEN is_principal = 1 THEN 'Principal'
    ELSE 'Secondaire'
  END AS type_shop,
  capital_actuel
FROM shops
ORDER BY is_principal DESC, designation ASC;
```

### Vérifier si un Shop Principal existe déjà

```sql
SELECT EXISTS(SELECT 1 FROM shops WHERE is_principal = 1) AS has_principal_shop;
```

---

## 🎯 Cas d'Usage

### Scénario 1: Entreprise avec 1 Siège + Plusieurs Agences

```
Shop Principal: UCASH Siège (Kinshasa)
├── Shop Secondaire: UCASH Goma
├── Shop Secondaire: UCASH Lubumbashi
├── Shop Secondaire: UCASH Bukavu
└── Shop Secondaire: UCASH Kisangani
```

### Scénario 2: Multi-Pays

```
Shop Principal: UCASH Central RDC (Kinshasa)
├── Shop Secondaire: UCASH Kampala (Ouganda)
├── Shop Secondaire: UCASH Nairobi (Kenya)
└── Shop Secondaire: UCASH Kigali (Rwanda)
```

---

## 🔍 Avantages

### 1. **Organisation Claire**
- Distinction visuelle entre siège et agences
- Hiérarchie claire de l'entreprise

### 2. **Rapports Consolidés**
- Possibilité de générer des rapports par type de shop
- Statistiques globales vs par agence

### 3. **Gestion des Permissions**
- Permissions spécifiques pour le shop principal
- Règles de gestion différentes selon le type

### 4. **Suivi Amélioré**
- Identifier rapidement le shop central
- Analyses comparatives siège vs agences

---

## ⚙️ Configuration par Défaut

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `isPrincipal` | `false` | Tous les shops sont secondaires par défaut |
| Type de champ | `TINYINT(1)` | 0 = Secondaire, 1 = Principal |
| Index | `idx_shops_is_principal` | Optimisation des requêtes |

---

## 🔒 Règles Métier

### Recommandations

1. **Un seul shop principal par entreprise** (recommandé mais pas forcé)
2. **Le premier shop créé devrait être le principal**
3. **Le shop principal ne devrait pas être supprimé facilement**

### Contraintes Optionnelles (À implémenter si nécessaire)

```sql
-- Empêcher plus d'un shop principal (optionnel)
CREATE TRIGGER prevent_multiple_principal_shops
BEFORE INSERT ON shops
FOR EACH ROW
BEGIN
  IF NEW.is_principal = 1 AND EXISTS(SELECT 1 FROM shops WHERE is_principal = 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un shop principal existe déjà';
  END IF;
END;
```

---

## 📝 Notes Importantes

- ✅ **Rétrocompatibilité**: Tous les shops existants sont automatiquement marqués comme secondaires (`is_principal = 0`)
- ✅ **Synchronisation**: Le champ `is_principal` est automatiquement synchronisé entre mobile et serveur
- ✅ **Valeur par défaut**: Si non spécifié, un shop est créé comme secondaire
- ✅ **Modification**: Un shop peut être promu de secondaire à principal (et vice versa) via l'API de mise à jour

---

## 🐛 Dépannage

### Problème: La case à cocher ne s'affiche pas

**Solution**: Vérifiez que vous utilisez la dernière version de `create_shop_dialog.dart`

### Problème: Erreur SQL lors de la création

**Solution**: Assurez-vous que la migration SQL a été appliquée:

```sql
SHOW COLUMNS FROM shops LIKE 'is_principal';
```

Si la colonne n'existe pas, exécutez la migration.

### Problème: Le champ `isPrincipal` n'est pas synchronisé

**Solution**: Vérifiez que `SyncManager.php` a été mis à jour avec le champ `is_principal`.

---

## 📅 Historique

- **Date**: Janvier 2026
- **Version**: UCASH v1.0
- **Auteur**: Équipe UCASH
- **Statut**: ✅ Implémenté et testé

---

## 🔗 Fichiers Modifiés

### Frontend (Flutter)
- ✅ `lib/models/shop_model.dart`
- ✅ `lib/widgets/create_shop_dialog.dart`
- ✅ `lib/services/shop_service.dart`

### Backend (PHP)
- ✅ `server/api/shops/update.php`
- ✅ `server/classes/SyncManager.php`

### Base de Données
- ✅ `database/add_is_principal_to_shops.sql`

### Documentation
- ✅ `SHOP_PRINCIPAL_FEATURE.md` (ce fichier)

---

## ✅ Checklist de Déploiement

- [ ] Appliquer la migration SQL sur la base de données de production
- [ ] Déployer le nouveau code PHP sur le serveur
- [ ] Mettre à jour l'application Flutter
- [ ] Tester la création d'un shop principal
- [ ] Tester la création d'un shop secondaire
- [ ] Vérifier la synchronisation
- [ ] Former les administrateurs sur cette nouvelle fonctionnalité

---

**🎉 Fonctionnalité Shop Principal implémentée avec succès!**
