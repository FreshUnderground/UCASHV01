# Flots Administratifs - Documentation

## 📋 Vue d'ensemble

Les **Flots Administratifs** permettent aux administrateurs de créer des mouvements entre shops qui :
- ✅ **Créent des dettes inter-shops** (comptabilisées dans les rapports)
- ✅ **Attribuent des frais** à chaque shop
- ❌ **N'impactent PAS le cash disponible** (pas de mouvement physique d'argent)

Cette fonctionnalité est utile pour :
- Régulariser des comptes entre shops
- Enregistrer des dettes administratives
- Attribuer des frais ou pénalités sans mouvement de cash réel

---

## 🎯 Fonctionnement

### Création d'un Flot Administratif

1. L'admin accède au **Dashboard Admin**
2. Clique sur le bouton **"Flot Administratif"** dans les actions rapides
3. Remplit le formulaire :
   - **Shop Source** : Le shop qui doit (débiteur)
   - **Shop Destination** : Le shop créancier
   - **Date du Flot** : Date de l'opération (par défaut: aujourd'hui)
   - **Montant** : Montant de la dette en USD
   - **Frais Shop Source** (optionnel) : Frais attribués au shop source
   - **Frais Shop Destination** (optionnel) : Frais attribués au shop destination
   - **Notes** : Raison/description du flot administratif

### Impacts du Flot Administratif

#### ✅ Ce qui EST impacté :

1. **Dettes Inter-Shops** :
   - Le shop source **doit** le montant au shop destination
   - Visible dans le rapport "Dettes Intershop"
   - Calcul automatique dans `_calculerComptesShops()`

2. **Compte FRAIS** :
   - Les frais spécifiés sont ajoutés au compte FRAIS de chaque shop
   - Type de transaction : `COMMISSION_AUTO`
   - Visibles dans le widget "Comptes Spéciaux"

3. **Opérations** :
   - Enregistré comme une opération de type `flotShopToShop`
   - Marqué avec `isAdministrative = true`
   - Statut : `validee` (immédiatement validé)

#### ❌ Ce qui N'EST PAS impacté :

1. **Cash Disponible** :
   - Exclu du calcul dans `_calculerFlots()`
   - Filtre : `f.isAdministrative == false`
   - Aucun impact sur les rapports de clôture

2. **Capital du Shop** :
   - Pas de modification du capital cash
   - Pas de modification des modes de paiement

---

## 💻 Implémentation Technique

### 1. Modèle de Données

#### `OperationModel` (lib/models/operation_model.dart)
```dart
final bool isAdministrative; // Défaut: false
```

#### Base de Données MySQL
```sql
ALTER TABLE operations 
ADD COLUMN is_administrative BOOLEAN DEFAULT FALSE;
```

### 2. Service de Calcul

#### Exclusion du Cash Disponible (lib/services/rapport_cloture_service.dart)
```dart
// Flots reçus - EXCLUSION des flots administratifs
final flotsRecusServis = operations.where((f) =>
    f.type == OperationType.flotShopToShop &&
    f.shopDestinationId == shopId &&
    f.statut == OperationStatus.validee &&
    f.isAdministrative == false && // ← EXCLUSION CRITIQUE
    _isSameDay(f.dateValidation ?? f.createdAt ?? f.dateOp, dateRapport)
).toList();
```

#### Inclusion dans les Dettes Inter-Shops
```dart
// Tous les flots (y compris administratifs) sont inclus
final allFlots = operations.where((op) => 
    op.type == OperationType.flotShopToShop
).toList();
```

### 3. Interface Utilisateur

#### Dialog de Création (`lib/widgets/admin_flot_dialog.dart`)
- Formulaire avec validation
- Sélection des shops
- Montants et frais
- Notes/raison obligatoire

#### Bouton dans Dashboard Admin (`lib/pages/dashboard_admin.dart`)
- Section "Actions Rapides"
- Icône: `Icons.admin_panel_settings`
- Couleur: Violet (`0xFF9333EA`)

---

## 📊 Exemple d'Utilisation

### Scénario : Régularisation de Compte

**Situation** :
- Shop A a servi des transferts pour Shop B
- Shop B doit 500 USD à Shop A
- Shop A facture 50 USD de frais de service

**Action de l'Admin** :
1. Créer un flot administratif :
   - Shop Source : **Shop B** (débiteur)
   - Shop Destination : **Shop A** (créancier)
   - Date : **15/11/2025** (date de la régularisation)
   - Montant : **500 USD**
   - Frais Shop A : **50 USD**
   - Notes : "Régularisation transferts Novembre 2025"

**Résultats** :
- ✅ Rapport Dettes Intershop : Shop B doit 500 USD à Shop A
- ✅ Compte FRAIS Shop A : +50 USD
- ❌ Cash Disponible Shop A : **Inchangé**
- ❌ Cash Disponible Shop B : **Inchangé**

---

## 🔍 Vérifications

### 1. Vérifier la Migration SQL
```sql
USE ucash_db;
SHOW COLUMNS FROM operations LIKE 'is_administrative';
```

Résultat attendu :
```
+------------------+---------+------+-----+---------+-------+
| Field            | Type    | Null | Key | Default | Extra |
+------------------+---------+------+-----+---------+-------+
| is_administrative| tinyint | YES  | MUL | 0       |       |
+------------------+---------+------+-----+---------+-------+
```

### 2. Vérifier un Flot Administratif Créé
```sql
SELECT 
    id,
    code_ops,
    shop_source_id,
    shop_destination_id,
    montant_net,
    is_administrative,
    notes
FROM operations 
WHERE is_administrative = 1
ORDER BY created_at DESC 
LIMIT 5;
```

### 3. Vérifier les Frais Attribués
```sql
SELECT 
    cs.id,
    cs.type,
    cs.montant,
    cs.description,
    cs.shop_id,
    cs.operation_id
FROM comptes_speciaux cs
JOIN operations op ON cs.operation_id = op.id
WHERE op.is_administrative = 1
ORDER BY cs.created_at DESC;
```

---

## 📝 Notes Importantes

1. **Permissions** :
   - Seuls les **admins** peuvent créer des flots administratifs
   - Le bouton n'est visible que dans le dashboard admin

2. **Synchronisation** :
   - Les flots administratifs se synchronisent comme les flots normaux
   - Le champ `is_administrative` est inclus dans la sync

3. **Rapports** :
   - **Dettes Intershop** : Inclus (créent des dettes)
   - **Cash Disponible** : Exclus (pas d'impact cash)
   - **Comptes Spéciaux** : Frais visibles si attribués

4. **Audit Trail** :
   - Notes obligatoires pour traçabilité
   - Préfixe automatique : "FLOT ADMINISTRATIF -"
   - lastModifiedBy : `admin_{username}`

5. **Sélection de Date** :
   - Permet de créer des flots avec une date passée
   - Utile pour régulariser des dettes anciennes
   - La date sélectionnée est utilisée pour `dateOp` et `dateValidation`
   - La `createdAt` reste toujours la date actuelle (pour l'audit)

---

## 🚀 Déploiement

### Méthode Automatique (Recommandée)

Exécuter le script de déploiement :
```bash
deploy_flots_administratifs.bat
```

Ce script va automatiquement :
1. ✅ Exécuter la migration SQL
2. ✅ Déployer les fichiers PHP mis à jour
3. ✅ Afficher un résumé des changements

### Méthode Manuelle

#### Étape 1 : Migration SQL
```bash
mysql -u root -p ucash_db < database/add_is_administrative_to_operations.sql
```

#### Étape 2 : Déployer les fichiers PHP
Copier vers le serveur :
- `server/api/sync/operations/upload.php`
- `server/api/sync/operations/changes.php`

#### Étape 3 : Redémarrer l'application
```bash
flutter run
```

### Fichiers Modifiés

**Flutter** :
- `lib/models/operation_model.dart` - Champ `isAdministrative`
- `lib/widgets/admin_flot_dialog.dart` - Dialog + sélecteur de date
- `lib/services/rapport_cloture_service.dart` - Exclusion cash + frais manuels
- `lib/pages/dashboard_admin.dart` - Bouton

**Serveur** :
- `server/api/sync/operations/upload.php` - INSERT/UPDATE `is_administrative`
- `server/api/sync/operations/changes.php` - SELECT `is_administrative`

**Base de données** :
- `database/add_is_administrative_to_operations.sql`

### Étapes de Déploiement

1. **Exécuter la migration SQL** :
   ```bash
   mysql -u root -p ucash_db < database/add_is_administrative_to_operations.sql
   ```

2. **Synchroniser le code Flutter** :
   - Le modèle `OperationModel` est déjà mis à jour
   - Les services incluent la logique d'exclusion
   - L'UI inclut le bouton et le dialog

3. **Tester la fonctionnalité** :
   - Créer un flot administratif de test
   - Vérifier qu'il apparaît dans Dettes Intershop
   - Vérifier qu'il n'impacte PAS le cash disponible
   - Vérifier que les frais sont bien attribués

---

## 🐛 Troubleshooting

### Problème : Flot administratif impacte le cash

**Cause** : Le filtre `isAdministrative == false` n'est pas appliqué  
**Solution** : Vérifier `rapport_cloture_service.dart` lignes 266-292

### Problème : Frais non attribués

**Cause** : Erreur lors de la création des transactions FRAIS  
**Solution** : Vérifier les logs pour les erreurs de `CompteSpecialService`

### Problème : Champ `is_administrative` NULL dans MySQL

**Cause** : Migration non exécutée  
**Solution** : Exécuter le script SQL `add_is_administrative_to_operations.sql`

---

**Date de création** : 11 Décembre 2025  
**Version** : 1.0  
**Auteur** : UCASH Development Team  
**Status** : ✅ Implémenté et Testé
