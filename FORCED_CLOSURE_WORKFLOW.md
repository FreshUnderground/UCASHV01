# 🔄 Flux de Clôture Virtuelle Automatique

## 📋 Vue d'Ensemble

Lorsqu'un agent ouvre le **Menu Virtuel** (Gestion Virtuelle), le système vérifie automatiquement si les jours précédents ont été clôturés. Si des clôtures manquent, un dialogue s'affiche pour proposer de les générer automatiquement.

## 🎯 Fonctionnalités

### 1. Vérification Automatique au Démarrage

**Déclencheur**: Ouverture du menu Virtuel (`virtual_transactions_widget.dart`)

**Fichier**: `lib/widgets/virtual_transactions_widget.dart` (lignes 76-80, 106-156)

```dart
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 4, vsync: this);
  _selectedDate = DateTime.now();
  _loadData();
  // ✅ Vérifier les jours non clôturés après le chargement
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _verifierJoursNonClotures();
    }
  });
}
```

### 2. Logique de Vérification

**Méthode**: `_verifierJoursNonClotures()`

**Processus**:

1. **Récupérer les SIMs** du shop
2. **Chercher les jours manquants** (jusqu'à 14 jours en arrière)
3. **S'arrêter** dès qu'on trouve une clôture existante
4. **Proposer** de clôturer les jours manquants

```
Aujourd'hui: 4 décembre 2025
│
├─ 3 déc ❌ Pas de clôture → Ajouter à la liste
├─ 2 déc ❌ Pas de clôture → Ajouter à la liste  
├─ 1er déc ✅ Clôture trouvée → STOP
└─ (on ne vérifie pas plus loin)

→ Jours à clôturer: 2 décembre, 3 décembre
```

### 3. Dialogue Interactif

**Méthode**: `_proposerClotureMassive()`

**Interface**:

```
┌────────────────────────────────────────┐
│ ⚠️  Clôtures Manquantes                │
├────────────────────────────────────────┤
│                                        │
│ Les 2 journées suivantes n'ont pas     │
│ été clôturées:                         │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 02/12/2025, 03/12/2025             │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Voulez-vous clôturer ces journées      │
│ avec les mêmes montants?               │
│                                        │
│                [Plus tard]  [Clôturer] │
└────────────────────────────────────────┘
```

**Options**:

- **1 jour manquant**: Bouton "Clôturer"
- **2-3 jours**: "Clôturer les X jours"
- **4+ jours**: "Clôturer tout (X jours)"
- **Plus tard**: Fermer sans action

### 4. Génération Automatique

**Méthode**: `_genererClotureForce()`

**Processus**:

1. **Générer les clôtures** avec `ClotureVirtuelleParSimService.genererClotureParSim()`
   - Utilise les soldes actuels des SIMs
   - Calcule automatiquement les frais
   - Récupère le solde antérieur de la dernière clôture

2. **Confirmer** avec un dialogue simple:
   ```
   Clôture du 02/12/2025
   Générer la clôture automatiquement 
   avec les soldes actuels?
   
   [Annuler]  [Confirmer]
   ```

3. **Sauvegarder** les clôtures générées

4. **Vérifier** s'il reste d'autres jours (récursif)

## 🔄 Flux Complet

```
┌──────────────────────────────────────────────┐
│ Agent ouvre Menu Virtuel                     │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ initState() → addPostFrameCallback()         │
│              _verifierJoursNonClotures()     │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Récupérer SIMs du shop                       │
│ Chercher jours non clôturés (max 14 jours)   │
└──────────────┬───────────────────────────────┘
               │
               ├─ Aucun jour manquant → Continuer normalement
               │
               └─ Jours manquants trouvés ▼
                  
┌──────────────────────────────────────────────┐
│ Afficher dialogue "Clôtures Manquantes"      │
│ Lister les dates: 02/12, 03/12...           │
└──────────────┬───────────────────────────────┘
               │
               ├─ "Plus tard" → Fermer
               │
               └─ "Clôturer" ▼
                  
┌──────────────────────────────────────────────┐
│ Pour chaque jour (du plus ancien au récent): │
│                                               │
│ 1. _genererClotureForce(date)                │
│    ├─ Générer clôtures par SIM               │
│    ├─ Dialogue confirmation                  │
│    └─ Sauvegarder                            │
│                                               │
│ 2. Passer au jour suivant (récursif)         │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ ✅ Toutes les clôtures sauvegardées          │
│ Notification: "X clôture(s) sauvegardée(s)"  │
│ Continuer vers le Menu Virtuel               │
└──────────────────────────────────────────────┘
```

## 📊 Données Générées

Pour chaque jour non clôturé, le système crée automatiquement:

### Par SIM:
- **Solde Antérieur**: Dernière clôture de cette SIM
- **Solde Actuel**: Calculé automatiquement
  ```
  = Solde Antérieur 
    + Captures du jour
    - Servies du jour
    - Retraits du jour
    - Dépôts clients du jour
  ```
- **Frais Antérieur**: Frais total de la dernière clôture
- **Frais du Jour**: Somme des frais des transactions validées
- **Frais Total**: Frais Antérieur + Frais du Jour
- **Cash Disponible**: 0 (peut être ajusté manuellement plus tard)

## 🎨 Exemples d'Utilisation

### Cas 1: Un Seul Jour Manquant (Dimanche)

```
Aujourd'hui: Lundi 4 décembre
Dernier clôturé: Samedi 2 décembre
→ Dimanche 3 décembre non clôturé

Dialogue:
┌────────────────────────────────────┐
│ ⚠️  Clôtures Manquantes            │
│                                    │
│ La journée suivante n'a pas été    │
│ clôturée:                          │
│                                    │
│ 03/12/2025                         │
│                                    │
│ [Plus tard]         [Clôturer]     │
└────────────────────────────────────┘
```

### Cas 2: Plusieurs Jours (Week-end + Lundi)

```
Aujourd'hui: Mardi 5 décembre
Dernier clôturé: Vendredi 1er décembre
→ Samedi 2, Dimanche 3, Lundi 4 non clôturés

Dialogue:
┌────────────────────────────────────┐
│ ⚠️  Clôtures Manquantes            │
│                                    │
│ Les 3 journées suivantes n'ont pas │
│ été clôturées:                     │
│                                    │
│ 02/12, 03/12, 04/12               │
│                                    │
│ [Plus tard]  [Clôturer les 3 jours]│
└────────────────────────────────────┘
```

### Cas 3: Longue Absence (> 3 jours)

```
Aujourd'hui: Lundi 11 décembre
Dernier clôturé: Lundi 4 décembre
→ 5, 6, 7, 8, 9, 10 décembre non clôturés

Dialogue:
┌────────────────────────────────────┐
│ ⚠️  Clôtures Manquantes            │
│                                    │
│ Les 6 journées suivantes n'ont pas │
│ été clôturées:                     │
│                                    │
│ 05/12, 06/12, 07/12, 08/12,       │
│ 09/12, 10/12                       │
│                                    │
│ Voulez-vous clôturer toutes ces    │
│ journées en une fois?              │
│                                    │
│ [Plus tard]  [Clôturer tout (6 j)] │
└────────────────────────────────────┘
```

## 🔧 Configuration

### Paramètres Modifiables

**Fichier**: `lib/widgets/virtual_transactions_widget.dart`

**Ligne 126**: Nombre de jours à vérifier
```dart
final dateDebut = aujourdhui.subtract(const Duration(days: 14)); // Max 14 jours
```

**Ligne 167-168**: Condition pour affichage du dialogue
```dart
barrierDismissible: false, // L'agent DOIT choisir une action
```

## ⚙️ Fonctionnalités Futures (TODO)

### 1. Clôture Massive avec Même Montant
Actuellement, chaque jour est clôturé individuellement. À implémenter:
```dart
// Ligne 311: TODO dans _cloturerTousLesJours()
// Implémenter la clôture des jours suivants avec les mêmes montants
// Pour l'instant, on redemande pour chaque jour
```

**Proposition**:
- Lors de la première clôture, mémoriser les montants saisis
- Appliquer automatiquement aux jours suivants
- Permettre l'ajustement si nécessaire

### 2. Ignorer Définitivement
Permettre à l'agent d'ignorer certains jours (ex: shop fermé)

### 3. Notification Persistante
Badge sur l'icône du Menu Virtuel indiquant le nombre de jours à clôturer

## 🐛 Gestion d'Erreurs

### Erreur: Aucune SIM trouvée
```
⚠️ Aucune SIM trouvée pour le shop X
→ Ne pas afficher le dialogue
→ Continuer normalement
```

### Erreur: Échec de génération
```
❌ Erreur génération clôture forcée: [détails]
→ Afficher SnackBar rouge
→ Permettre à l'agent de réessayer
```

### Erreur: Shop ID manquant
```
currentUser?.shopId == null
→ Return silencieusement
→ Pas d'affichage
```

## 📝 Notes Techniques

### Performance
- Vérification limitée à 14 jours (évite les requêtes excessives)
- Arrêt dès qu'une clôture est trouvée (optimisation)
- Utilisation de `addPostFrameCallback` (évite les erreurs de build)

### Sécurité
- Vérification `mounted` avant chaque setState
- Dialogues non-dismissibles (forcer un choix)
- Gestion d'erreurs avec try-catch

### UX
- Messages contextuels selon le nombre de jours
- Progression récursive (jour par jour si accepté)
- Feedback immédiat (SnackBar de confirmation)

---

**Date de Création**: 4 Décembre 2025  
**Fichier Principal**: `lib/widgets/virtual_transactions_widget.dart`  
**Lignes Modifiées**: 76-80, 106-371  
**Status**: ✅ Implémenté et documenté
