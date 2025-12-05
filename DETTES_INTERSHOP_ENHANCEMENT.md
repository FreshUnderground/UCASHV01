# Enhancement: Dettes par Shop + Évolution Quotidienne - Rapport Intershop

## 🎯 Objectifs des améliorations

### Amélioration 1 : Dettes par Shop
L'utilisateur a demandé d'afficher **"Dettes /shop que nous devons ou qui nous doit. et selon la periode selectionner"**

### Amélioration 2 : Évolution Quotidienne
L'utilisateur a demandé un suivi jour par jour :
**"25/12/2024 : Dette Antérieur : 500$ Créance 3000 Dettes 15300 Solde : 11800"**

Cette amélioration ajoute une section au rapport qui affiche clairement :
- ✅ **Shops qui nous doivent** (créances)
- ✅ **Shops que nous devons** (dettes)
- ✅ Basé sur la période sélectionnée
- ✅ Avec le solde net par shop

## 📊 Évolution Quotidienne des Dettes

### Affichage par Jour
Chaque jour affiche maintenant une carte détaillée avec :

```
┌─────────────────────────────────────────┐
│ 📅 25/12/2024              [5 ops]  │
├─────────────────────────────────────────┤
│ 🕙 Dette Antérieure: 500.00 USD   │
├─────────────────────────────────────────┤
│ ➕ Créances    │ ➖ Dettes       │
│    3,000.00    │   15,300.00     │
├─────────────────────────────────────────┤
│ Solde du jour:   -12,300.00 USD    │
│ 📉 Solde Cumulé:  -11,800.00 USD    │
└─────────────────────────────────────────┘
```

### Champs Affichés

1. **Date** : Date du mouvement (format DD/MM/YYYY)
2. **Nombre d'opérations** : Badge indiquant le nombre de transactions ce jour-là
3. **Dette Antérieure** : Solde cumulé du jour précédent
4. **Créances du jour** : Total des créances générées ce jour
5. **Dettes du jour** : Total des dettes générées ce jour
6. **Solde du jour** : Créances - Dettes du jour
7. **Solde Cumulé** : Dette antérieure + Solde du jour

### Formule de Calcul

```dart
// Pour chaque jour (du plus ancien au plus récent)
DetteAntérieure = SoldeCumuléDuJourPrécédent
SoldeDuJour = CréancesDuJour - DettesDuJour
SoldeCumulé = DetteAntérieure + SoldeDuJour

// Le solde cumulé devient la dette antérieure du jour suivant
```

### Exemple de Séquence

**Jour 1 (23/12/2024)**
- Dette antérieure : 0.00 USD
- Créances : 5,000.00 USD
- Dettes : 2,000.00 USD
- Solde jour : +3,000.00 USD
- **Solde cumulé : +3,000.00 USD** ✅

**Jour 2 (24/12/2024)**
- Dette antérieure : 3,000.00 USD (du jour 1)
- Créances : 1,000.00 USD
- Dettes : 6,500.00 USD
- Solde jour : -5,500.00 USD
- **Solde cumulé : -2,500.00 USD** ❌

**Jour 3 (25/12/2024)**
- Dette antérieure : -2,500.00 USD (du jour 2)
- Créances : 3,000.00 USD
- Dettes : 15,300.00 USD
- Solde jour : -12,300.00 USD
- **Solde cumulé : -14,800.00 USD** ❌

## 📊 Design Visuel de l'Évolution Quotidienne

### Affichage Conditionnel
La section s'affiche **UNIQUEMENT** lorsqu'un shop spécifique est sélectionné (pas en vue globale "Tous les shops").

### Contenu de la Section

#### 📗 Shops qui nous doivent (Créances)
```
┌─────────────────────────────────────────┐
│ 🔼 Shops qui nous doivent    [2 shops]  │
├─────────────────────────────────────────┤
│ 🏪 Shop NGANGAZU                        │
│    ➤ 15,000.00 USD                      │
│    ├─ Créances: 20,000.00               │
│    └─ Dettes:    5,000.00               │
├─────────────────────────────────────────┤
│ 🏪 Shop BUKAVU                          │
│    ➤ 8,500.00 USD                       │
└─────────────────────────────────────────┘
```

#### 📕 Shops que nous devons (Dettes)
```
┌─────────────────────────────────────────┐
│ 🔽 Shops que nous devons     [1 shop]   │
├─────────────────────────────────────────┤
│ 🏪 Shop GOMA                            │
│    ➤ 12,300.00 USD                      │
│    ├─ Créances:  3,000.00               │
│    └─ Dettes:   15,300.00               │
└─────────────────────────────────────────┘
```

## 🔧 Modifications Techniques

### 1. Service de Rapport (report_service.dart)

#### Nouvelle Structure de Données
```dart
final Map<int, Map<String, dynamic>> soldesParShop = {};
```

#### Calcul des Soldes
Pour chaque transfert et flot :
- Identifier le shop concerné
- Accumuler les créances (+)
- Accumuler les dettes (-)
- Calculer le solde net

#### Séparation des Shops
```dart
// Shops créanciers (solde > 0)
final shopsNousDoivent = soldesParShop.values
    .where((s) => (s['solde'] as double) > 0)
    .toList()
  ..sort((a, b) => (b['solde'] as double).compareTo(a['solde'] as double));

// Shops débiteurs (solde < 0)
final shopsNousDevons = soldesParShop.values
    .where((s) => (s['solde'] as double) < 0)
    .toList()
  ..sort((a, b) => (a['solde'] as double).compareTo(b['solde'] as double));
```

#### Données Retournées
```dart
return {
  // ... autres données ...
  'shopsNousDoivent': shopsNousDoivent,   // NOUVEAU
  'shopsNousDevons': shopsNousDevons,     // NOUVEAU
  'mouvements': mouvements,
  'mouvementsParJour': joursListe,
};
```

### 2. Widget du Rapport (dettes_intershop_report.dart)

#### Nouvelle Méthode : `_buildShopsBreakdown()`
- Vérifie si un shop spécifique est sélectionné
- Affiche les deux sections (créances et dettes)
- Gère le cas où il n'y a aucune dette

#### Méthode Auxiliaire : `_buildShopCard()`
- Affiche une carte pour chaque shop
- Montre le solde net en grand
- Affiche le détail créances/dettes si les deux existent

#### Méthode Auxiliaire : `_buildShopDetailItem()`
- Affiche un item de détail (créance ou dette)
- Format compact pour mobile

## 📱 Design Responsive

### Mobile
- Cartes compactes empilées verticalement
- Icônes plus petites (16-18px)
- Texte réduit (14-16px)

### Desktop/Tablet
- Cartes plus espacées
- Icônes normales (20-24px)
- Texte normal (16-18px)

## 🎨 Code Couleur

| Type | Couleur | Usage |
|------|---------|-------|
| **Créances** | 🟢 Vert | Shops qui nous doivent |
| **Dettes** | 🔴 Rouge | Shops que nous devons |
| **Solde Positif** | 🟢 Vert | Solde net créancier |
| **Solde Négatif** | 🔴 Rouge | Solde net débiteur |

## 💼 Cas d'Usage

### Exemple 1 : Shop avec Créances Uniquement
**Shop MOKU** consulte le rapport pour la période du 1-30 Nov 2024 :
- **Shops qui nous doivent** :
  - NGANGAZU : 15,000 USD
  - BUKAVU : 8,500 USD
- **Shops que nous devons** : (aucun)

### Exemple 2 : Shop avec Créances et Dettes
**Shop GOMA** consulte le rapport :
- **Shops qui nous doivent** :
  - BUKAVU : 5,000 USD
- **Shops que nous devons** :
  - MOKU : 12,300 USD
  - NGANGAZU : 7,200 USD

### Exemple 3 : Compensation Automatique
**Shop A** et **Shop B** ont des mouvements croisés :
- A doit 10,000 USD à B (transfert)
- B doit 6,000 USD à A (flot)
- **Résultat affiché** : A doit 4,000 USD à B (solde net)

## ✅ Avantages de l'Amélioration

1. **Clarté Immédiate** : Vue directe des dettes par shop
2. **Réconciliation Facilitée** : Identification rapide des shops concernés
3. **Priorisation** : Tri par montant pour traiter les dettes importantes
4. **Détail Complet** : Voir créances ET dettes pour un même shop
5. **Période Flexible** : Filtrage par dates pour analyse historique

## 🔍 Exemples de Requêtes Résolues

### Question : "Quel shop me doit le plus d'argent ?"
**Réponse** : Première carte dans "Shops qui nous doivent"

### Question : "À combien se monte ma dette envers Shop NGANGAZU ?"
**Réponse** : Chercher NGANGAZU dans "Shops que nous devons"

### Question : "Ai-je des dettes et créances avec le même shop ?"
**Réponse** : Visible dans le détail de chaque carte

## 📈 Flux de Données

```
Période sélectionnée
        ↓
Filtrer transferts et flots
        ↓
Pour chaque opération:
  - Si créance → +montant au shop concerné
  - Si dette → -montant au shop concerné
        ↓
Calculer solde net par shop
        ↓
Séparer en deux listes:
  - Solde > 0 → Shops qui nous doivent
  - Solde < 0 → Shops que nous devons
        ↓
Trier et afficher
```

## 🚀 Fichiers Modifiés

1. **lib/services/report_service.dart** (+81 lignes)
   - Ajout calcul soldes par shop
   - Séparation créanciers/débiteurs
   - Export des données

2. **lib/widgets/reports/dettes_intershop_report.dart** (+276 lignes)
   - Méthode `_buildShopsBreakdown()`
   - Méthode `_buildShopCard()`
   - Méthode `_buildShopDetailItem()`
   - Intégration dans le layout principal

3. **DETTES_INTERSHOP_RAPPORT.md** (+27 lignes)
   - Documentation mise à jour
   - Exemples d'utilisation

## 🎯 Résultat Final

L'utilisateur peut maintenant :
- ✅ Sélectionner un shop
- ✅ Choisir une période
- ✅ Voir **clairement** qui lui doit de l'argent
- ✅ Voir **clairement** à qui il doit de l'argent
- ✅ Connaître le solde net avec chaque shop
- ✅ Planifier les règlements inter-shops

---

**Date** : Décembre 2024  
**Version** : 1.1  
**Status** : ✅ Opérationnel et Testé
