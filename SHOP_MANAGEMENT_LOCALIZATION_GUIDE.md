# 🌍 Guide de Localisation - Gestion Complète des Shops

## 📋 **Traductions Ajoutées**

### **110 nouvelles clés de traduction** pour la gestion complète des shops:

| Catégorie | Anglais | Français |
|-----------|---------|----------|
| **Gestion Générale** | Shop Management | Gestion des Shops |
| **Actions** | New Shop, Edit Shop, Delete Shop | Nouveau Shop, Modifier le Shop, Supprimer le Shop |
| **Formulaires** | Designation, Location | Désignation, Localisation |
| **Capitaux** | Cash Capital, Total Capital | Capital Cash, Capital Total |
| **Statistiques** | Total Shops, Active Shops | Total Shops, Shops Actifs |
| **Messages** | Shop created successfully! | Shop créé avec succès ! |
| **Sync** | Synced, Not Synced | Synchronisé, Non Synchronisé |

---

## 🎯 **Widgets à Localiser**

### 1. **create_shop_dialog.dart** (297 lignes)

**Textes à localiser:**
```dart
// AVANT (Français hardcodé)
Text('Nouveau Shop')
InputDecoration(labelText: 'Désignation *')
InputDecoration(labelText: 'Localisation *')
Text('Capitaux par Type de Caisse (USD)')
InputDecoration(labelText: 'Capital Cash *')
Text('Créer le Shop')

// APRÈS (Multilingue)
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final l10n = AppLocalizations.of(context)!;

Text(l10n.newShop)
InputDecoration(labelText: '${l10n.designation} *')
InputDecoration(labelText: '${l10n.location} *')
Text(l10n.capitalByType)
InputDecoration(labelText: '${l10n.capitalCash} *')
Text(l10n.createShop)
```

**Messages de validation:**
```dart
// AVANT
return 'La désignation est requise';
return 'La désignation doit contenir au moins 3 caractères';
return 'La localisation est requise';
return 'Le capital Cash est requis';
return 'Le capital doit être un nombre positif ou zéro';

// APRÈS
return l10n.designationRequired;
return l10n.designationMinLength;
return l10n.locationRequired;
return l10n.capitalCashRequired;
return l10n.capitalMustBePositive;
```

**Messages de succès/erreur:**
```dart
// AVANT
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Shop créé avec succès!')),
);

// APRÈS
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(l10n.shopCreatedSuccessfully)),
);
```

---

### 2. **edit_shop_dialog.dart** (Similar to create)

**Changements principaux:**
```dart
// Titre
Text('Modifier le Shop') → Text(l10n.editShop)

// Bouton
Text('Mettre à jour le Shop') → Text(l10n.updateShop)

// Message succès
'Shop mis à jour avec succès!' → l10n.shopUpdatedSuccessfully
```

---

### 3. **shops_management.dart** (617 lignes)

**En-tête:**
```dart
// AVANT
Text('Gestion des Shops')
Text('Actualiser')
Text('Nouveau Shop')

// APRÈS
Text(l10n.shopsManagement)
Text(l10n.refresh)
Text(l10n.newShop)
```

**Statistiques:**
```dart
// AVANT
_buildStatCard('Total Shops', '${stats['totalShops']}', ...)
_buildStatCard('Capital Total', '...', ...)
_buildStatCard('Capital Moyen', '...', ...)
_buildStatCard('Shops Actifs', '...', ...)

// APRÈS
_buildStatCard(l10n.totalShops, '${stats['totalShops']}', ...)
_buildStatCard(l10n.totalCapital, '...', ...)
_buildStatCard(l10n.averageCapital, '...', ...)
_buildStatCard(l10n.activeShops, '...', ...)
```

**Tableau:**
```dart
// En-têtes de colonnes
Text('Désignation') → Text(l10n.designation)
Text('Localisation') → Text(l10n.location)
Text('Capital') → Text(l10n.totalCapital)
Text('Agents') → Text(l10n.agentsCount)
Text('Actions') → Text(l10n.actions)
```

**Menu d'actions:**
```dart
PopupMenuItem(child: Text('Modifier')) → PopupMenuItem(child: Text(l10n.edit))
PopupMenuItem(child: Text('Ajuster le Capital')) → PopupMenuItem(child: Text(l10n.adjustCapital))
PopupMenuItem(child: Text('Supprimer')) → PopupMenuItem(child: Text(l10n.delete))
```

**Dialogue de confirmation:**
```dart
// AVANT
AlertDialog(
  title: Text('Supprimer le Shop?'),
  content: Text('Êtes-vous sûr de vouloir supprimer ce shop?'),
  actions: [
    TextButton(child: Text('Annuler'), ...),
    TextButton(child: Text('Supprimer'), ...),
  ],
)

// APRÈS
AlertDialog(
  title: Text(l10n.deleteShop),
  content: Text(l10n.confirmDeleteShop),
  actions: [
    TextButton(child: Text(l10n.cancel), ...),
    TextButton(child: Text(l10n.delete), ...),
  ],
)
```

---

### 4. **client_shop_info_widget.dart** (Déjà localisé)

✅ Ce widget affiche les infos du shop au client - déjà fait!

---

## 🎨 **Template de Localisation**

### **Étape 1: Import**
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### **Étape 2: Obtenir l'instance**
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return ...
}
```

### **Étape 3: Remplacer les strings**
```dart
// Texte simple
Text('Gestion des Shops') → Text(l10n.shopsManagement)

// Avec interpolation
Text('Total: $count shops') → Text('${l10n.total}: $count ${l10n.shops}')

// Dans InputDecoration
InputDecoration(
  labelText: 'Désignation',
  hintText: 'Ex: UCASH Central',
) 
→
InputDecoration(
  labelText: l10n.designation,
  hintText: 'Ex: UCASH Central', // Exemples peuvent rester en dur
)

// Dans validateur
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'La désignation est requise';
  }
  return null;
}
→
validator: (value) {
  if (value == null || value.isEmpty) {
    return l10n.designationRequired;
  }
  return null;
}
```

---

## 📊 **Liste Complète des Clés Ajoutées**

```json
{
  // Titres et Navigation
  "shopManagement": "Shop Management / Gestion des Shops",
  "shopsManagement": "Shops Management / Gestion des Shops",
  "newShop": "New Shop / Nouveau Shop",
  "editShop": "Edit Shop / Modifier le Shop",
  "deleteShop": "Delete Shop / Supprimer le Shop",
  "shopDetails": "Shop Details / Détails du Shop",
  "shopInformation": "Shop Information / Informations du Shop",
  
  // Formulaires
  "designation": "Designation / Désignation",
  "designationRequired": "Designation is required / La désignation est requise",
  "designationMinLength": "Designation must contain at least 3 characters / ...",
  "locationRequired": "Location is required / La localisation est requise",
  
  // Capitaux
  "capitalByType": "Capital by Cash Type (USD) / Capitaux par Type de Caisse (USD)",
  "capitalCash": "Cash Capital / Capital Cash",
  "capitalCashRequired": "Cash capital is required / Le capital Cash est requis",
  "capitalMustBePositive": "Capital must be a positive number or zero / ...",
  "capitalAirtelMoney": "Airtel Money Capital / Capital Airtel Money",
  "capitalMPesa": "M-Pesa Capital / Capital M-Pesa",
  "capitalOrangeMoney": "Orange Money Capital / Capital Orange Money",
  "totalCapital": "Total Capital / Capital Total",
  "averageCapital": "Average Capital / Capital Moyen",
  "initialCapital": "Initial Capital / Capital Initial",
  
  // Statistiques
  "activeShops": "Active Shops / Shops Actifs",
  "totalShops": "Total Shops / Total Shops",
  "agentsCount": "Agents / Agents",
  
  // Actions
  "creating": "Creating... / Création...",
  "updating": "Updating... / Mise à jour...",
  "createShop": "Create Shop / Créer le Shop",
  "updateShop": "Update Shop / Mettre à jour le Shop",
  "actions": "Actions / Actions",
  "view": "View / Voir",
  "viewDetails": "View Details / Voir les détails",
  
  // Messages de succès
  "shopCreatedSuccessfully": "Shop created successfully! / Shop créé avec succès !",
  "shopUpdatedSuccessfully": "Shop updated successfully! / Shop mis à jour avec succès !",
  "shopDeletedSuccessfully": "Shop deleted successfully! / Shop supprimé avec succès !",
  
  // Messages d'erreur
  "errorCreatingShop": "Error creating shop / Erreur lors de la création du shop",
  "errorUpdatingShop": "Error updating shop / Erreur lors de la mise à jour du shop",
  "errorDeletingShop": "Error deleting shop / Erreur lors de la suppression du shop",
  
  // Confirmations
  "confirmDeleteShop": "Are you sure you want to delete this shop? / Êtes-vous sûr...",
  "thisActionCannotBeUndone": "This action cannot be undone. / Cette action ne peut pas...",
  "shopHasAgents": "This shop has agents assigned to it. / Ce shop a des agents...",
  "allAgentsWillBeUnassigned": "All agents will be unassigned. / Tous les agents seront...",
  
  // États vides
  "noShopsFound": "No shops found / Aucun shop trouvé",
  "createFirstShop": "Create your first shop to get started / Créez votre premier shop...",
  
  // Autres champs
  "primaryCurrency": "Primary Currency / Devise Principale",
  "secondaryCurrency": "Secondary Currency / Devise Secondaire",
  "debts": "Debts / Dettes",
  "credits": "Credits / Créances",
  "lastModified": "Last Modified / Dernière Modification",
  "createdAt": "Created At / Créé le",
  
  // Synchronisation
  "syncStatus": "Sync Status / Statut de Sync",
  "synced": "Synced / Synchronisé",
  "notSynced": "Not Synced / Non Synchronisé",
  "syncPending": "Sync Pending / En attente de sync"
}
```

---

## ✅ **Checklist de Localisation des Shops**

### **Fichiers ARB**
- [x] ✅ app_en.arb - 55 clés ajoutées
- [x] ✅ app_fr.arb - 55 clés ajoutées

### **Widgets à Localiser**
- [ ] ⏳ create_shop_dialog.dart (297 lignes)
- [ ] ⏳ edit_shop_dialog.dart (similar)
- [ ] ⏳ shops_management.dart (617 lignes)
- [x] ✅ client_shop_info_widget.dart (déjà fait)
- [x] ✅ capital_adjustment_dialog_tracked.dart (déjà fait)
- [x] ✅ capital_adjustments_history.dart (déjà fait)

### **Services**
- [ ] ⏳ shop_service.dart - Messages debug peuvent rester en anglais
- [x] ✅ capital_adjustment_service.dart - Déjà localisé

---

## 🚀 **Prochaines Étapes**

### **1. Localiser create_shop_dialog.dart**

<function_calls>
<invoke name="search_replace">
<parameter name="file_path">...