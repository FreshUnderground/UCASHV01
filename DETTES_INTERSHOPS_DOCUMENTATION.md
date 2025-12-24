# UCASH - Documentation des Dettes Intershops et Situation Nette

## Vue d'Ensemble

Le système UCASH implémente un mécanisme sophistiqué de gestion des dettes intershops et de calcul de la situation nette de l'entreprise. Cette documentation détaille les algorithmes, formules et logiques métier utilisés dans le rapport de clôture journalier.

---

## Architecture du Système de Dettes Intershops

### Composants Principaux

#### 1. Service de Calcul (`rapport_cloture_service.dart`)
- **Fonction**: `_getComptesShops()` - Calcul des dettes/créances inter-shops
- **Algorithme**: Logique bidirectionnelle basée sur les flux financiers
- **Données**: Transferts, flots, opérations cross-shop, règlements triangulaires

#### 2. Modèle de Données (`rapport_cloture_model.dart`)
- **Structure**: `RapportClotureModel` avec sections dédiées aux dettes
- **Champs**: `shopsNousDoivent`, `shopsNousDevons`, `triangularSettlements`
- **Calculs**: Totaux automatiques et validation croisée

#### 3. Interface Utilisateur (`rapportcloture.dart`)
- **Affichage**: Sections détaillées des créances et dettes
- **Visualisation**: Règlements triangulaires avec rôles et impacts
- **Formule**: Décomposition complète du capital net

---

## Logique de Calcul des Dettes Intershops

### 1. Transferts - Logique Bidirectionnelle

```dart
// TRANSFERTS SERVIS PAR NOUS → Ils nous doivent le MONTANT BRUT
if (operation.shopDestinationId == shopId) {
    soldesParShop[autreShopId] += operation.montantBrut; // CRÉANCE (+)
    debugPrint('Transfert SERVI: Shop $autreShopId nous doit +${operation.montantBrut} USD');
}

// TRANSFERTS INITIÉS PAR NOUS → Nous leur devons le MONTANT BRUT  
if (operation.shopSourceId == shopId) {
    soldesParShop[autreShopId] -= operation.montantBrut; // DETTE (-)
    debugPrint('Transfert INITIÉ: On doit à Shop $autreShopId -${operation.montantBrut} USD');
}
```

**Principe**: 
- Shop qui sert le transfert → Créance (garde commission + sert montant net)
- Shop qui initie le transfert → Dette (doit montant brut au shop serveur)

### 2. Flots - Quatre Scénarios

#### A. Flots En Attente
```dart
// FLOTS EN ATTENTE ENVOYÉS
if (flot.shopSourceId == shopId && flot.statut == OperationStatus.enAttente) {
    soldesParShop[autreShopId] += flot.montantNet; // Ils nous doivent rembourser
}

// FLOTS EN ATTENTE REÇUS
if (flot.shopDestinationId == shopId && flot.statut == OperationStatus.enAttente) {
    soldesParShop[autreShopId] -= flot.montantNet; // On leur doit rembourser
}
```

#### B. Flots Validés
```dart
// FLOTS VALIDÉS REÇUS
if (flot.shopDestinationId == shopId && flot.statut == OperationStatus.validee) {
    soldesParShop[autreShopId] -= flot.montantNet; // On leur doit rembourser
}

// FLOTS VALIDÉS ENVOYÉS
if (flot.shopSourceId == shopId && flot.statut == OperationStatus.validee) {
    soldesParShop[autreShopId] += flot.montantNet; // Ils nous doivent rembourser
}
```

### 3. Opérations Cross-Shop

#### A. Retraits Cross-Shop
```dart
// RETRAITS où nous sommes destinataires → Ils nous doivent
final retraitsAutresShop = operations.where((op) =>
    op.type == OperationType.retrait &&
    op.shopDestinationId == shopId &&
    op.shopSourceId != shopId
);

for (final retrait in retraitsAutresShop) {
    soldesParShop[autreShopId] += retrait.montantNet; // CRÉANCE (+)
}
```

#### B. Dépôts Cross-Shop
```dart
// DÉPÔTS où nous sommes destinataires → Nous leur devons
final depotsAutresShop = operations.where((op) =>
    op.type == OperationType.depot &&
    op.shopDestinationId == shopId &&
    op.shopSourceId != shopId
);

for (final depot in depotsAutresShop) {
    soldesParShop[autreShopId] -= depot.montantNet; // DETTE (-)
}
```

### 4. Règlements Triangulaires

#### Principe
**Scénario**: Shop A doit à Shop C, Shop A paie Shop B pour le compte de Shop C
**Résultat**: Dette A→C diminue, Dette B→C augmente

#### Implémentation
```dart
for (final settlement in triangularSettlements) {
    final debtorId = settlement.shopDebtorId;
    final intermediaryId = settlement.shopIntermediaryId;
    final creditorId = settlement.shopCreditorId;
    final amount = settlement.montant;
    
    if (shopId == creditorId) {
        // Pour le créancier: Dette débiteur diminue, dette intermédiaire augmente
        soldesParShop[debtorId] -= amount;
        soldesParShop[intermediaryId] += amount;
    } else if (shopId == debtorId) {
        // Pour le débiteur: Dette diminue, créance sur intermédiaire diminue
        soldesParShop[creditorId] += amount;
        soldesParShop[intermediaryId] -= amount;
    } else if (shopId == intermediaryId) {
        // Pour l'intermédiaire: Dette vers débiteur diminue, dette vers créancier augmente
        soldesParShop[debtorId] += amount;
        soldesParShop[creditorId] -= amount;
    }
}
```

---

## Calcul de la Situation Nette

### Formule Complète

```dart
final capitalNet = cashDisponibleTotal +           // Liquidités réelles
                   totalShopsNousDoivent -         // + Créances inter-shops
                   totalShopsNousDevons -          // - Dettes inter-shops
                   (soldeFraisAnterieur +          // - Solde frais antérieur
                    commissionsFraisDuJour -       // + Commissions du jour
                    retraitsFraisDuJour) -         // - Retraits frais du jour
                   transfertsEnAttente +           // - Engagements à honorer
                   totalSoldePartenaire;           // + Solde net partenaires
```

### Composants Détaillés

#### A. Cash Disponible
- **Composition**: Solde cash physique + Solde virtuel des SIMs
- **Source**: Clôture précédente + Mouvements du jour
- **Ajustements**: Déjà diminué des retraits FRAIS

#### B. Créances/Dettes Inter-Shops
- **Calcul**: Dynamique selon logique bidirectionnelle
- **Compensation**: Automatique des positions
- **Règlements**: Impact des triangulaires appliqué

#### C. Solde Frais
- **Formule**: Frais antérieur + Commissions jour - Retraits jour
- **Continuité**: Report du solde de la clôture précédente
- **Traçabilité**: Détail par shop et type d'opération

#### D. Transferts En Attente
- **Impact**: Négatif sur la situation nette
- **Raison**: Engagements à honorer (cash à débourser)
- **Calcul**: Somme des transferts statut `enAttente`

#### E. Solde Net Partenaires
- **Composition**: Créances partenaires - Dettes partenaires
- **Basé sur**: Dépôts/retraits de comptes clients
- **Exclusions**: Opérations administratives

---

## Principes Directeurs

### 1. Logique Bidirectionnelle
- **Principe**: Chaque opération a deux impacts (source et destination)
- **Détermination**: Position relative détermine créance ou dette
- **Compensation**: Automatique des flux croisés

### 2. Montants Bruts vs Nets
- **Transferts**: Utiliser montant BRUT (inclut commission)
- **Flots**: Utiliser montant NET (commission déjà déduite)
- **Cohérence**: Selon le type d'opération et la logique métier

### 3. Temporalité
- **Opérations du jour**: Pour les mouvements courants
- **Soldes antérieurs**: Pour la continuité
- **Règlements triangulaires**: Filtrés par date du rapport

### 4. Exclusions
- **Opérations administratives**: `isAdministrative=true` exclues
- **Flots administratifs**: Exclus du cash disponible
- **Séparation**: Claire entre métier et administratif

### 5. Validation et Cohérence
- **Vérification**: Des soldes par shop
- **Détection**: D'écarts et incohérences
- **Traçabilité**: Complète avec logs détaillés

---

## Affichage dans le Rapport

### Sections du Rapport

#### 1. Shops Qui Nous Doivent (DIFF. DETTES)
- **Contenu**: Liste des shops créanciers
- **Détails**: Désignation, localisation, montant
- **Total**: Somme automatique des créances

#### 2. Shops Que Nous Devons
- **Contenu**: Liste des shops débiteurs
- **Détails**: Désignation, localisation, montant
- **Total**: Somme automatique des dettes

#### 3. Règlements Triangulaires (RÉGULARISATION)
- **Affichage**: Tableau avec référence, montant, rôle, impact
- **Rôles**: Débiteur, Intermédiaire, Créancier
- **Impacts**: Dette diminue/augmente/aucun impact
- **Couleurs**: Vert (diminue), Rouge (augmente), Gris (aucun)

#### 4. Capital Net Final
- **Formule**: Décomposition ligne par ligne
- **Vérification**: Calcul affiché = calcul service
- **Couleurs**: Bleu (positif), Rouge (négatif)

---

## Maintenance et Évolution

### Bonnes Pratiques

#### 1. Ajout de Nouveaux Types d'Opérations
```dart
// Template pour nouveaux types
if (operation.type == OperationType.NOUVEAU_TYPE) {
    if (operation.shopDestinationId == shopId) {
        // Logique pour shop destination
        soldesParShop[autreShopId] += operation.montant; // ou -=
    }
    if (operation.shopSourceId == shopId) {
        // Logique pour shop source
        soldesParShop[autreShopId] -= operation.montant; // ou +=
    }
}
```

#### 2. Debug et Traçabilité
```dart
debugPrint('📊 NOUVEAU TYPE: Shop $autreShopId impact ${operation.montant} USD');
```

#### 3. Tests de Cohérence
```dart
// Vérifier que la somme des soldes = 0 (conservation)
final sommeGlobale = soldesParShop.values.fold(0.0, (sum, solde) => sum + solde);
assert(sommeGlobale.abs() < 0.01, 'Incohérence détectée: $sommeGlobale');
```

### Points d'Attention

#### 1. Gestion des Devises
- **USD**: Devise principale pour les calculs
- **CDF**: Conversion automatique si nécessaire
- **Cohérence**: Vérifier la devise avant calculs

#### 2. Gestion des Dates
- **Filtrage**: Utiliser `_isSameDay()` pour les opérations du jour
- **Règlements**: Filtrer par date de règlement
- **Continuité**: Soldes antérieurs du jour précédent

#### 3. Performance
- **Optimisation**: Éviter les requêtes répétitives
- **Cache**: Utiliser des maps pour accès rapide aux shops
- **Indexation**: Assurer les index sur les clés étrangères

---

## Cas d'Usage et Exemples

### Exemple 1: Transfert Inter-Shop
```
Scénario: Client à Shop A envoie 100 USD à client à Shop B
- Shop A (source): Reçoit 100 USD du client + 5 USD commission
- Shop B (destination): Doit servir 100 USD au client
- Résultat: Shop A doit 105 USD à Shop B (montant brut)
```

### Exemple 2: Flot de Liquidité
```
Scénario: Shop A envoie 1000 USD de flot à Shop B
- Shop A: Solde diminue de 1000 USD
- Shop B: Doit rembourser 1000 USD à Shop A
- Résultat: Shop B doit 1000 USD à Shop A
```

### Exemple 3: Règlement Triangulaire
```
Scénario: Shop A doit 500 USD à Shop C, Shop B doit 500 USD à Shop A
- Avant: A→C: -500, B→A: -500, B→C: 0
- Règlement: B paie directement 500 USD à C pour A
- Après: A→C: 0, B→A: 0, B→C: -500
```

---

## Intégration avec Autres Modules

### 1. Synchronisation
- **Upload**: Règlements triangulaires vers serveur
- **Download**: Récupération des règlements autres shops
- **Conflit**: Résolution automatique par timestamp

### 2. Rapports
- **Historique**: Conservation des rapports de clôture
- **Analytics**: Évolution des dettes dans le temps
- **Alertes**: Seuils de dette configurable

### 3. Validation
- **Workflow**: Validation admin → agent pour règlements
- **Traçabilité**: Historique des modifications
- **Audit**: Logs complets des calculs

---

*Cette documentation technique fournit une référence complète pour comprendre, maintenir et étendre le système de gestion des dettes intershops dans UCASH.*

**Version**: 1.0  
**Dernière mise à jour**: Décembre 2024  
**Auteur**: Système UCASH
