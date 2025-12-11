# Fix: Gestion des Frais - Filtre par Shop Destination

## 🎯 Objectif

Corriger la logique de filtrage dans la **Gestion des Frais** pour afficher les opérations de la période et du shop sélectionné (admin) en tenant compte que **le shop doit être la destination** et suivre la logique des frais utilisée dans la clôture.

## ⚠️ Problème Identifié

Avant cette correction, la fonction `getFraisParShopDestination` dans le service des comptes spéciaux filtrait incorrectement les opérations. La logique ne suivait pas le principe de la clôture :

**Règle métier de la clôture** : Les frais appartiennent au **shop DESTINATION** (celui qui sert le transfert), pas au shop source.

## ✅ Solution Implémentée

### Fichier Modifié

**`lib/services/compte_special_service.dart`** - Fonction `getFraisParShopDestination()`

### Changements Principaux

#### 1. **Clarification de la Logique**

Ajout d'un commentaire explicite pour documenter la logique de clôture :

```dart
/// Obtenir les frais groupés par SHOP DESTINATION (qui encaisse les frais)
/// LOGIQUE DE CLÔTURE: Les frais appartiennent au shop DESTINATION (qui sert le transfert)
```

#### 2. **Filtrage par Shop Destination**

La fonction filtre maintenant correctement les opérations où le `shop_destination_id` correspond au shop sélectionné (pour l'admin) :

```dart
// LOGIQUE DE CLÔTURE: Le shop DESTINATION encaisse les frais
// Filtrer les opérations où shopId est la DESTINATION
final shopDestIdRaw = opData['shop_destination_id'];
final shopDestId = shopDestIdRaw is int ? shopDestIdRaw : (shopDestIdRaw is String ? int.tryParse(shopDestIdRaw) : null);

if (shopDestId == null) {
  filteredByShopDest++;
  continue;
}

// Si un shopId est spécifié (admin sélectionne un shop), filtrer par ce shop DESTINATION
if (shopId != null && shopDestId != shopId) {
  filteredByShopDest++;
  continue;
}
```

#### 3. **Filtrage par Période**

Le filtrage par date respecte maintenant la période sélectionnée avec compteurs de debug :

```dart
if (startDate != null) {
  final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
  if (dateValidation.isBefore(startOfDay)) {
    filteredByDate++;
    continue;
  }
}
if (endDate != null) {
  final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
  if (dateValidation.isAfter(endOfDay)) {
    filteredByDate++;
    continue;
  }
}
```

#### 4. **Filtrage par Type et Statut**

Seuls les transferts validés sont pris en compte :

```dart
// Vérifier le type d'opération (transferts uniquement)
final type = opData['type']?.toString();
if (!(type == 'transfertNational' ||
     type == 'transfertInternationalEntrant' ||
     type == 'transfertInternationalSortant')) {
  filteredByType++;
  continue;
}

// Vérifier le statut (validée uniquement)
final statut = opData['statut']?.toString();
if (statut != 'validee') {
  filteredByStatut++;
  continue;
}
```

#### 5. **Amélioration du Debugging**

Ajout de compteurs détaillés pour suivre le filtrage :

```dart
int totalOperations = 0;
int filteredByShopDest = 0;
int filteredByType = 0;
int filteredByStatut = 0;
int filteredByDate = 0;
int validOperations = 0;

// ... après filtrage ...

debugPrint('📊 Filtrage terminé:');
debugPrint('   Total opérations: $totalOperations');
debugPrint('   Filtrées par shop destination: $filteredByShopDest');
debugPrint('   Filtrées par type: $filteredByType');
debugPrint('   Filtrées par statut: $filteredByStatut');
debugPrint('   Filtrées par date: $filteredByDate');
debugPrint('   ✅ Opérations valides: $validOperations');
```

#### 6. **Groupement par Shop Source**

Les frais sont groupés par **shop source** (qui a envoyé le transfert vers notre shop destination) :

```dart
// Grouper les frais par shop SOURCE (qui a envoyé le transfert au shop DESTINATION)
final Map<int, Map<String, dynamic>> parShopSource = {};

// ...

// Grouper par shop source (qui a envoyé le transfert)
if (!parShopSource.containsKey(shopSrcId)) {
  parShopSource[shopSrcId] = {
    'montant': 0.0,
    'count': 0,
    'details': <Map<String, dynamic>>[],
  };
}
```

## 🔍 Logique de Clôture Respectée

Cette correction aligne la **Gestion des Frais** avec la logique utilisée dans la clôture (voir `rapport_cloture_service.dart`) :

### Principe de la Clôture pour les Frais

```dart
// Transferts SERVIS par le shop (où le shop est DESTINATION) - frais gagnés
final transfertsServis = operations.where((op) =>
    op.shopDestinationId == shopId && // Nous sommes le shop destination
    (op.type == OperationType.transfertNational ||
     op.type == OperationType.transfertInternationalEntrant ||
     op.type == OperationType.transfertInternationalSortant) &&
    op.statut == OperationStatus.validee &&
    _isSameDay(op.createdAt ?? op.dateOp, dateRapport)
).toList();
```

### Impact sur l'Interface

Lorsqu'un **admin** sélectionne un shop et une période dans **Gestion des Frais** :

1. ✅ Seuls les transferts où ce shop est **DESTINATION** sont affichés
2. ✅ Seuls les transferts de la période sélectionnée sont inclus
3. ✅ Seuls les transferts avec statut **validée** sont comptabilisés
4. ✅ Les frais sont groupés par shop **source** (pour voir d'où viennent les transferts)

## 📊 Exemple d'Utilisation

### Scénario : Admin sélectionne "Shop Kinshasa" pour la période du 1-10 Décembre 2025

**Résultat attendu** :
- Affiche tous les transferts reçus par "Shop Kinshasa" (en tant que destination)
- Groupés par shop source : "Shop Lubumbashi", "Shop Goma", etc.
- Période : 1-10 Décembre 2025
- Statut : Validée uniquement

**Avant le fix** : Pouvait afficher des opérations incorrectes ne respectant pas la destination
**Après le fix** : Affiche uniquement les frais encaissés par Shop Kinshasa dans la période

## ✅ Tests Recommandés

1. **Test Admin avec Shop Sélectionné**
   - Sélectionner un shop spécifique
   - Sélectionner une période
   - Vérifier que seuls les transferts reçus par ce shop sont affichés

2. **Test Admin sans Shop (Tous les Shops)**
   - Ne pas sélectionner de shop
   - Vérifier que tous les shops destinations sont affichés

3. **Test Période**
   - Sélectionner différentes périodes
   - Vérifier que seules les opérations de la période sont incluses

4. **Test Filtrage par Statut**
   - Vérifier que seuls les transferts validés sont affichés
   - Les transferts en attente ou annulés ne doivent pas apparaître

## 📝 Cohérence avec la Clôture

Cette correction garantit que :
- La **Gestion des Frais** affiche les mêmes données que la **Clôture**
- Les frais encaissés correspondent aux transferts servis (destination)
- Les rapports financiers sont cohérents
- Les admins voient des données précises par shop et période

## 🔗 Fichiers Liés

- `lib/services/compte_special_service.dart` - Service modifié
- `lib/services/rapport_cloture_service.dart` - Logique de référence pour les frais
- `lib/widgets/comptes_speciaux_widget.dart` - Interface utilisateur de gestion des frais

---

**Date de Modification** : 11 Décembre 2025  
**Impact** : Amélioration de la précision du filtrage des frais par shop destination et période
