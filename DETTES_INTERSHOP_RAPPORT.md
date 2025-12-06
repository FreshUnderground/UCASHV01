# Rapport des Mouvements des Dettes Intershop Journalier

## 📊 Vue d'ensemble

Un nouveau rapport a été ajouté au système UCASH pour suivre les mouvements quotidiens des dettes et créances entre les shops. Ce rapport est accessible via le menu **RAPPORT/DETTES** dans le tableau de bord administrateur.

## 🎯 Objectif

Ce rapport permet de :
- Visualiser les mouvements quotidiens de dettes entre shops
- Suivre l'évolution des créances et dettes jour par jour
- Identifier rapidement les transferts et FLOTs qui créent des obligations financières
- Faciliter la réconciliation entre shops

## 📍 Accès au Rapport

### Navigation
1. Connectez-vous en tant qu'**ADMIN**
2. Accédez au menu **RAPPORTS**
3. Sélectionnez l'onglet **"Dettes Intershop"** (nouvel onglet ajouté)

### Filtres disponibles
- **Shop spécifique** : Voir les dettes d'un shop particulier
- **Tous les shops** : Vue globale de toutes les dettes inter-shops
- **Période** : Date de début et date de fin personnalisables

## 📋 Contenu du Rapport

### 1. Résumé Statistique (Cartes KPI)
Le rapport affiche 4 cartes principales :
- **Total Créances** : Montant total que les autres shops doivent
- **Total Dettes** : Montant total dû aux autres shops
- **Solde Net** : Différence entre créances et dettes
- **Mouvements** : Nombre total de transactions

### 2. Dettes par Shop (Quand un shop est sélectionné)
Affiche deux listes détaillées :

#### 📗 Shops qui Nous qui Doivent (Créances)
- Liste des shops avec leur créance
- Montant total par shop
- Détail créances vs dettes si les deux existent
- Trié par montant décroissant

#### 📕 Shops que Nous que Devons (Dettes)
- Liste des shops à qui on doit de l'argent
- Montant total par shop
- Détail créances vs dettes si les deux existent
- Trié par montant croissant (dette la plus élevée en premier)

### 3. Mouvements par Jour
### 3. Mouvements par Jour
Une vue chronologique regroupée par jour montrant :
- Date du mouvement
- Créances du jour
- Dettes du jour
- Solde net du jour
- Nombre d'opérations

### 4. Détail des Mouvements
Tableau détaillé de chaque mouvement incluant :
- **Date et heure** de l'opération
- **Shop source** (qui a initié)
- **Shop destination** (qui a reçu/servi)
- **Type de mouvement** :
  - `Transfert Servi` : Shop a servi un transfert → Créance
  - `Transfert Initié` : Shop a initié un transfert → Dette
  - `Flot Envoyé` : Shop a envoyé un flot → Créance
  - `Flot Reçu` : Shop a reçu un flot → Dette
- **Montant** de l'opération
- **Description** contextuelle

## 💡 Logique Métier

### Calcul des Soldes par Shop
Lorsqu'un shop spécifique est sélectionné, le rapport calcule :
- **Pour chaque autre shop** : 
  - Créances = montants que l'autre shop nous doit
  - Dettes = montants qu'on doit à l'autre shop
  - Solde = Créances - Dettes
- **Si Solde > 0** : Shop nous doit (affiché dans "Shops qui Nous qui Doivent")
- **Si Solde < 0** : On doit au shop (affiché dans "Shops que Nous que Devons")

### Pour les Transferts
```
Transfert National ou International :
├─ Shop SOURCE reçoit le cash du client
├─ Shop DESTINATION sert le bénéficiaire
└─ Dette créée : Shop SOURCE doit le montant BRUT au Shop DESTINATION
```

**Exemple :**
- Client paie 105 USD à Shop MOKU pour un transfert
- Shop NGANGAZU sert 100 USD au bénéficiaire
- **Dette** : MOKU doit 105 USD à NGANGAZU

### Pour les FLOTs
```
Flot Shop-to-Shop :
├─ Shop A envoie de l'argent à Shop B
└─ Dette créée : Shop B doit rembourser Shop A
```

**Exemple :**
- Shop MOKU envoie 10,000 USD en flot à Shop NGANGAZU
- **Créance** : NGANGAZU doit 10,000 USD à MOKU

## 🖥️ Interface Utilisateur

### Version Desktop
- Tableau complet avec toutes les colonnes
- Affichage jusqu'à 50 mouvements
- Filtres et tri disponibles

### Version Mobile/Tablet
- Cartes condensées pour chaque mouvement
- Navigation optimisée
- Affichage jusqu'à 20 mouvements

## 🔧 Fichiers Modifiés/Créés

### Nouveau fichier
- `lib/widgets/reports/dettes_intershop_report.dart` (679 lignes)
  - Widget principal du rapport
  - Interface responsive
  - Visualisations des mouvements

### Fichiers modifiés
1. **`lib/services/report_service.dart`**
   - Nouvelle méthode : `generateDettesIntershopReport()`
   - Logique de calcul des dettes par jour
   - Agrégation des transferts et flots

2. **`lib/widgets/reports/admin_reports_widget.dart`**
   - Ajout d'un nouvel onglet "Dettes Intershop"
   - Intégration du nouveau rapport dans le TabBar
   - Version mobile et desktop

## 📊 Données Affichées

Le rapport compile automatiquement :
- ✅ Transferts nationaux
- ✅ Transferts internationaux (sortants et entrants)
- ✅ FLOTs shop-to-shop (envoyés et reçus)
- ✅ Statuts validés et en attente

## 🎨 Code Couleur

- **Vert** 🟢 : Créances (les autres Nous qui Doivent)
- **Rouge** 🔴 : Dettes (Nous que Devons aux autres)
- **Bleu** 🔵 : Nombre de mouvements
- **Orange** 🟠 : Transferts initiés
- **Violet** 🟣 : FLOTs reçus

## ✅ Avantages

1. **Transparence** : Vue claire des obligations financières
2. **Suivi quotidien** : Évolution jour par jour
3. **Réconciliation** : Facilite le règlement entre shops
4. **Audit** : Traçabilité complète des mouvements
5. **Multi-shop** : Vue globale ou par shop spécifique

## 🚀 Utilisation Recommandée

### Pour les Administrateurs
- Consulter le rapport **quotidiennement** pour suivre les dettes
- Utiliser la vue **"Tous les shops"** pour identifier les déséquilibres
- Exporter les données pour analyse externe (future fonctionnalité)

### Pour la Réconciliation
- Comparer avec les relevés bancaires
- Vérifier les montants avec les shops concernés
- Planifier les règlements entre shops

## 📈 Évolutions Futures Possibles

- Export PDF du rapport
- Export Excel/CSV
- Graphiques d'évolution des dettes
- Alertes automatiques pour dettes élevées
- Intégration avec le système de paiement inter-shops

## 🆘 Support

Pour toute question ou problème avec ce rapport :
1. Vérifier les filtres de date et shop
2. S'assurer que les opérations sont bien synchronisées
3. Contacter le support technique si nécessaire

---

**Date de création** : Décembre 2024  
**Version** : 1.0  
**Status** : ✅ Opérationnel
