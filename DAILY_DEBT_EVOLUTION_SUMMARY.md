# Résumé: Évolution Quotidienne des Dettes Intershop

## ✅ Fonctionnalité Ajoutée

Le rapport "Dettes Intershop" affiche maintenant un **suivi jour par jour** avec évolution cumulée des dettes et créances entre shops.

## 📊 Format d'Affichage

Chaque jour affiche:
```
📅 25/12/2024                           [5 opérations]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🕙 Dette Antérieure:                    500.00 USD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

➕ Créances              ➖ Dettes
   3,000.00                15,300.00

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Solde du jour:                      -12,300.00 USD
📉 Solde Cumulé:                     -11,800.00 USD
```

## 🧮 Logique de Calcul

### Formule
```
Dette Antérieure = Solde cumulé du jour précédent
Solde du Jour = Créances - Dettes
Solde Cumulé = Dette Antérieure + Solde du Jour
```

### Exemple Pratique

#### Période : 23-25 Décembre 2024

**23/12/2024**
- Dette antérieure : `0.00 USD` (début)
- Créances : `5,000.00 USD`
- Dettes : `2,000.00 USD`
- Solde jour : `+3,000.00 USD`
- **→ Solde cumulé : 3,000.00 USD** ✅

**24/12/2024**
- Dette antérieure : `3,000.00 USD` ← (du 23/12)
- Créances : `1,000.00 USD`
- Dettes : `6,500.00 USD`
- Solde jour : `-5,500.00 USD`
- **→ Solde cumulé : -2,500.00 USD** (3,000 - 5,500)

**25/12/2024**
- Dette antérieure : `-2,500.00 USD` ← (du 24/12)
- Créances : `3,000.00 USD`
- Dettes : `15,300.00 USD`
- Solde jour : `-12,300.00 USD`
- **→ Solde cumulé : -14,800.00 USD** (-2,500 - 12,300)

## 🎨 Couleurs Visuelles

| Élément | Condition | Couleur |
|---------|-----------|---------|
| Carte journalière | Solde cumulé ≥ 0 | 🟢 Fond vert pâle |
| Carte journalière | Solde cumulé < 0 | 🔴 Fond rouge pâle |
| Dette antérieure | ≥ 0 | 🟢 Vert |
| Dette antérieure | < 0 | 🔴 Rouge |
| Créances | Toujours | 🟢 Vert |
| Dettes | Toujours | 🔴 Rouge |
| Solde jour | ≥ 0 | 🟢 Vert |
| Solde jour | < 0 | 🔴 Rouge |
| Solde cumulé | ≥ 0 | 🟢 Vert + 📈 |
| Solde cumulé | < 0 | 🔴 Rouge + 📉 |

## 💻 Modifications Techniques

### Fichier: `report_service.dart`

#### Nouveau calcul d'évolution (+16 lignes)
```dart
// Calculer l'évolution quotidienne avec solde cumulé
final joursListe = mouvementsParJour.values.toList();
joursListe.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

double soldeAnterieur = 0.0;
for (final jour in joursListe) {
  jour['detteAnterieure'] = soldeAnterieur;
  final soldeJour = (jour['creances'] as double) - (jour['dettes'] as double);
  final soldeCumule = soldeAnterieur + soldeJour;
  jour['soldeCumule'] = soldeCumule;
  soldeAnterieur = soldeCumule;
}

// Trier par date décroissante pour l'affichage
joursListe.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
```

#### Nouvelles données dans le rapport
```dart
// Chaque jour contient maintenant:
{
  'date': '2024-12-25',
  'creances': 3000.0,
  'dettes': 15300.0,
  'solde': -12300.0,
  'detteAnterieure': -2500.0,      // ← NOUVEAU
  'soldeCumule': -14800.0,         // ← NOUVEAU
  'nombreOperations': 5,
}
```

### Fichier: `dettes_intershop_report.dart`

#### Carte journalière améliorée (+158 lignes)
- Fond gradué selon solde cumulé
- Bordure colorée (vert/rouge)
- Section "Dette Antérieure" avec icône historique
- Cartes créances/dettes avec icônes
- Section solde cumulé mise en évidence

#### Nouvelle méthode: `_buildDayDetailCard()`
Affiche créances et dettes dans des cartes visuelles avec icônes

## 🚀 Utilisation

### Accès
1. Login **ADMIN**
2. Menu **RAPPORTS**
3. Onglet **Dettes Intershop**
4. **Sélectionner un shop**
5. Choisir la période

### Lecture du Rapport

#### Question: "Quelle était ma situation au début du 25/12?"
**Réponse**: Regarder "Dette Antérieure" du 25/12

#### Question: "Combien j'ai gagné ou perdu le 25/12?"
**Réponse**: Regarder "Solde du jour" du 25/12

#### Question: "Quelle est ma situation finale après le 25/12?"
**Réponse**: Regarder "Solde Cumulé" du 25/12

#### Question: "Comment ma dette a évolué sur 3 jours?"
**Réponse**: Comparer les "Solde Cumulé" de chaque jour

## ✅ Avantages

1. **Vision Historique**: Voir l'évolution jour par jour
2. **Dette Antérieure**: Savoir la situation au début de chaque jour
3. **Accumulation Claire**: Comprendre comment les dettes s'accumulent
4. **Tendance Visuelle**: Couleurs indiquent si la situation s'améliore ou empire
5. **Réconciliation Facile**: Vérifier les montants quotidiens

## 📱 Responsive

### Mobile
- Cartes empilées verticalement
- Texte condensé (11-13px)
- Icônes 16-18px
- Padding réduit

### Desktop/Tablet
- Cartes plus espacées
- Texte normal (13-17px)
- Icônes 18-20px
- Padding généreux

## 🎯 Cas d'Usage Réels

### Scenario 1: Suivi de Remboursement
Un shop veut rembourser ses dettes progressivement:
- 23/12: Dette cumulée = -5,000 USD
- 24/12: Transfert de 2,000 USD → Dette = -3,000 USD
- 25/12: Transfert de 1,500 USD → Dette = -1,500 USD
- **Évolution visible jour par jour** ✅

### Scenario 2: Identification de Problème
Un shop voit sa dette augmenter:
- 23/12: Solde = +1,000 USD (créancier)
- 24/12: Solde = -500 USD (devient débiteur)
- 25/12: Solde = -3,000 USD (dette s'aggrave)
- **Alert visuelle avec couleur rouge** ⚠️

### Scenario 3: Réconciliation Mensuelle
À la fin du mois, comparer:
- Dette antérieure du 1er jour
- Solde cumulé du dernier jour
- Vérifier que = Solde final attendu

## 📊 Statistiques Affichées

Pour chaque jour:
- ✅ Nombre d'opérations
- ✅ Créances générées
- ✅ Dettes générées
- ✅ Solde du jour
- ✅ Dette reportée
- ✅ Solde cumulé

## 🔍 Exemple Complet

```
📅 23/12/2024                    [3 ops]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dette Antérieure:           0.00 USD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Créances: 5,000     Dettes: 2,000
Solde jour: +3,000.00 USD
📈 Solde Cumulé: +3,000.00 USD

📅 24/12/2024                    [4 ops]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dette Antérieure:       3,000.00 USD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Créances: 1,000     Dettes: 6,500
Solde jour: -5,500.00 USD
📉 Solde Cumulé: -2,500.00 USD

📅 25/12/2024                    [5 ops]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dette Antérieure:      -2,500.00 USD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Créances: 3,000     Dettes: 15,300
Solde jour: -12,300.00 USD
📉 Solde Cumulé: -14,800.00 USD
```

**Interprétation**:
- Situation a démarré créancier (+3,000)
- Devenu débiteur jour 2 (-2,500)
- Dette s'est aggravée jour 3 (-14,800)
- **Action requise**: Remboursement ou réduction dettes

---

**Date**: Décembre 2024  
**Version**: 2.0  
**Status**: ✅ Opérationnel et Testé
