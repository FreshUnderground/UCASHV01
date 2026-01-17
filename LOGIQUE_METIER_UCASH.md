# LOGIQUE MÉTIER - UCASH

## 📋 Vue d'ensemble

UCASH est une application de gestion financière pour les agences de transfert d'argent (Mobile Money, Western Union, etc.) permettant de gérer les opérations financières, les agents, les clients, les SIMs, et la comptabilité en temps réel.

---

## 🏗️ Architecture du Système

### Hiérarchie Organisationnelle

```
ADMINISTRATEUR (Admin)
    ↓
SHOPS (Agences/Points de vente)
    ↓
AGENTS (Employés des shops)
    ↓
CLIENTS (Clients finaux)
```

### Base de Données

- **Local**: SQLite (sur l'appareil de l'agent)
- **Serveur**: MySQL (backend PHP/REST API)
- **Synchronisation**: Bidirectionnelle automatique et robuste

---

## 💰 TYPES D'OPÉRATIONS FINANCIÈRES

### 1. **Transfert National**
Transfert d'argent à l'intérieur du pays.

**Flux financier:**
```
Client paie: Montant Brut + Commission
Shop encaisse: Montant Brut
Shop gagne: Commission
```

**Impact sur le cash:**
- Cash disponible: +Montant Brut
- Commission: +Commission

---

### 2. **Transfert International Sortant**
Envoi d'argent vers un autre pays.

**Flux financier:**
```
Client paie: Montant Brut + Commission
Shop encaisse: Montant Brut + Commission
Destinataire reçoit: Montant Net (après conversion)
```

**Impact sur le cash:**
- Cash disponible: +Montant Brut + Commission
- Dette inter-shops: Shop local doit verser à shop distant

---

### 3. **Transfert International Entrant**
Réception d'argent depuis un autre pays.

**Flux financier:**
```
Client reçoit: Montant Net
Shop décaisse: Montant Net
Shop gagne: Commission (payée par le shop émetteur)
```

**Impact sur le cash:**
- Cash disponible: -Montant Net
- Créance inter-shops: Shop distant doit rembourser

---

### 4. **Dépôt (Cash-In)**
Client dépose de l'argent sur son compte Mobile Money.

**Flux financier:**
```
Client dépose: Montant Brut
Shop encaisse: Montant Brut
Shop paie commission opérateur: Commission
Shop garde: Montant Net
```

**Impact sur le cash:**
- Cash disponible: +Montant Net
- Commission pour l'opérateur: -Commission

**Règles spéciales ADMIN:**
- Les dépôts faits par un administrateur ne génèrent PAS de commissions
- Permet à l'admin d'injecter du cash sans frais

---

### 5. **Retrait (Cash-Out / Retrait Mobile Money)**
Client retire de l'argent de son compte Mobile Money.

**Flux financier:**
```
Client retire: Montant Net
Shop décaisse: Montant Brut
Shop gagne commission: Commission
```

**Impact sur le cash:**
- Cash disponible: -Montant Brut
- Commission gagnée: +Commission

**Règles spéciales ADMIN:**
- Les retraits faits par un administrateur ne génèrent PAS de commissions
- Permet à l'admin de retirer du cash sans frais

---

### 6. **Virement**
Transfert de crédit virtuel entre clients.

**Flux financier:**
- Pas d'impact direct sur le cash physique
- Transfert virtuel uniquement

---

### 7. **FLOT (Mouvement de Liquidité Shop-to-Shop)**

#### 7.1 FLOT PHYSIQUE
Transfert réel de cash entre deux shops.

**Types de FLOT:**

##### A. FLOT NORMAL (Opérationnel)
```
Shop Source envoie: Montant
Shop Destination reçoit: Montant
Commission: 0 (pas de frais entre shops)
```

**Impact sur le cash:**
- Shop Source: Cash disponible -Montant
- Shop Destination: Cash disponible +Montant

##### B. FLOT ADMINISTRATIF
Transfert virtuel créant des dettes sans mouvement de cash réel.

**Caractéristiques:**
- `isAdministrative = true`
- N'impacte PAS le cash disponible immédiatement
- Crée une dette bilatérale entre shops
- Utilisé pour la comptabilité et le suivi des dettes

**Impact:**
- Cash disponible: AUCUN impact
- Dette bilatérale: Shop Source doit à Shop Destination

---

## 🔄 GESTION DES COMMISSIONS

### Règles de Commission

1. **Transferts (National/International)**
   - Commission payée par le client émetteur
   - Ajoutée au montant brut

2. **Dépôts**
   - Commission payée à l'opérateur Mobile Money
   - Déduite du montant encaissé
   - **EXCEPTION**: Admin ne paie pas de commission

3. **Retraits**
   - Commission gagnée par le shop
   - Déduite du compte client, gardée par le shop
   - **EXCEPTION**: Admin ne génère pas de commission

4. **FLOT Shop-to-Shop**
   - Commission = 0 (solidarité entre shops)

---

## 💵 CALCUL DU CASH DISPONIBLE

### Formule Globale

```
Cash Disponible = Capital Initial
                + Dépôts (montant net après commission)
                - Retraits (montant brut)
                + Transferts reçus
                - Transferts envoyés
                + FLOT reçus
                - FLOT envoyés
                + Commissions gagnées
                - Ajustements de capital
```

### Règles Importantes

1. **FLOT Administratifs**: N'impactent PAS le cash disponible
2. **Opérations Admin**: Dépôts/Retraits sans commission
3. **Capital Ajustable**: L'admin peut ajuster le capital d'un shop

---

## 📊 CLÔTURE DE CAISSE

### Types de Clôture

#### 1. Clôture Physique (Cash)
Clôture globale de toutes les opérations en cash du shop.

**Éléments calculés:**
```
- Cash Initial (solde précédent + capital)
- Cash Entrant (dépôts, transferts reçus)
- Cash Sortant (retraits, transferts envoyés)
- Commissions gagnées
- Frais versés
- Solde théorique attendu
- Solde réel compté (billetage)
- Écart (différence entre théorique et réel)
```

#### 2. Clôture Virtuelle (par SIM)
Clôture séparée pour chaque carte SIM Mobile Money.

**Par SIM calculé:**
```
- Solde initial SIM
- Crédits (dépôts)
- Débits (retraits)
- Solde final SIM
- Frais antérieurs (frais dus mais non encore déduits)
```

**Tracking des frais:**
- Les frais peuvent être accumulés (`frais_anterieur`)
- Permettent de gérer les frais en retard

---

## 🎯 GESTION DES CARTES SIM

### Informations SIM

```dart
- numero: Numéro de la carte SIM
- operateur: Airtel, Vodacom, Orange
- soldeInitial: Solde au démarrage
- shopId: Shop propriétaire
- estActive: Carte active ou pas
```

### Opérations sur SIM

1. **Crédit Virtuel**: Ajout de crédit sur une SIM
2. **Retrait Virtuel**: Retrait de crédit d'une SIM
3. **Suivi du solde**: Calcul automatique du solde
4. **Clôture par SIM**: Fermeture comptable par SIM

---

## 👥 GESTION DES CLIENTS

### Types de Clients

1. **Client Standard**
   - Associé à un shop spécifique
   - Historique des transactions
   - Relevé de compte disponible

2. **Client Administratif**
   - `shopId = NULL`
   - Client "global" accessible par tous les shops
   - Utilisé par les administrateurs

### Informations Client

```dart
- nom, prenom
- telephone
- adresse
- numero_piece (ID/Passeport)
- shopId (NULL si client admin)
- createdAt, lastModifiedAt
```

---

## 🔐 GESTION DES RÔLES

### 1. ADMINISTRATEUR (Admin)

**Droits:**
- Accès à tous les shops
- Création/modification/suppression de shops
- Création/modification/suppression d'agents
- Ajustement des capitaux
- Validation des suppressions sensibles
- Rapports globaux multi-shops
- Gestion des dettes inter-shops
- **Opérations sans commission** (dépôts/retraits)

**Restrictions:**
- Ne peut PAS faire de clôture de caisse
- Uniquement consultation et gestion

---

### 2. AGENT

**Droits:**
- Accès UNIQUEMENT à son shop assigné
- Création d'opérations financières
- Gestion des clients de son shop
- Gestion des SIMs de son shop
- Clôture de caisse quotidienne
- Rapports de son shop uniquement

**Restrictions:**
- Ne peut pas voir les autres shops
- Ne peut pas modifier les paramètres globaux
- Opérations limitées à son périmètre

---

## 🔄 SYNCHRONISATION

### Principe

L'application fonctionne en mode **offline-first**:
1. Toutes les opérations sont d'abord enregistrées localement (SQLite)
2. La synchronisation se fait automatiquement quand internet est disponible
3. Gestion des conflits automatique

### Types de Sync

#### 1. Upload (Local → Serveur)
```
- Opérations locales non synchronisées
- Clients nouveaux/modifiés
- Transferts en attente
- Suppressions en attente de validation
```

#### 2. Download (Serveur → Local)
```
- Mises à jour depuis d'autres agents
- Validations admin
- Modifications de configuration
```

#### 3. Sync Robuste
- Retry automatique en cas d'échec
- File d'attente des opérations à synchroniser
- Notifications sur état de synchronisation

---

## 📈 RAPPORTS ET STATISTIQUES

### Rapports Agent

1. **Mouvements de Caisse**
   - Historique détaillé des opérations
   - Par période, par type d'opération

2. **Clôture Journalière**
   - État des cash disponible
   - Écarts de caisse

3. **Historique des Clôtures**
   - Archives des clôtures passées

4. **Rapport des Commissions**
   - Commissions gagnées par période

### Rapports Admin

5. **Situation Nette Entreprise**
   - Position globale de tous les shops
   - Cash total disponible
   - Dettes inter-shops

6. **Rapports Multi-Shops**
   - Vue consolidée de toutes les agences
   - Comparaison des performances

7. **Dettes Bilatérales**
   - Suivi des dettes entre shops
   - Règlements de dettes triangulaires

---

## 🔔 SYSTÈME DE NOTIFICATIONS

### Types de Notifications

1. **Transferts en Attente**
   - Badge sur l'icône du menu
   - Notification sonore
   - Liste des transferts à traiter

2. **FLOT Reçus**
   - Alerte quand un shop reçoit un FLOT
   - Notification avec montant

3. **Synchronisation**
   - Succès/échec de sync
   - Nombre d'opérations synchronisées

---

## 🗑️ SUPPRESSION D'OPÉRATIONS

### Workflow

1. **Agent demande suppression**
   - Enregistrement en local avec statut "pending"
   - Sync vers serveur

2. **Admin valide/rejette**
   - Validation: L'opération est définitivement supprimée
   - Rejet: L'opération reste active

3. **Sync retour**
   - Le statut est synchronisé vers tous les agents
   - Mise à jour de l'interface

### Règles

- Seules les opérations récentes peuvent être supprimées
- Admin peut supprimer sans validation
- Traçabilité complète dans les logs

---

## 💳 CRÉDITS INTER-SHOP (CRÉDITS VIRTUELS)

### Concept Fondamental

Les **Crédits Inter-Shop** permettent à un shop de prêter de l'argent virtuel à un autre shop ou partenaire. C'est un système de crédit basé sur le **solde virtuel** disponible sur les cartes SIM Mobile Money.

### Workflow Complet

```
1. ACCORD DU CRÉDIT (Sortie Virtuelle)
   Shop A accorde crédit → Solde Virtuel SIM diminue
   ↓
2. BÉNÉFICIAIRE UTILISE LE CRÉDIT
   Shop B/Partenaire reçoit le crédit virtuel
   ↓
3. PAIEMENT (Entrée Cash)
   Shop B paie en cash → Cash du Shop A augmente
   ↓
4. CRÉDIT SOLDÉ
   Crédit marqué comme payé, cycle terminé
```

---

### Types de Bénéficiaires

#### 1. **Shop** (Autre agence)
```dart
typeBeneficiaire: 'shop'
```
- Crédit accordé à un autre shop du réseau
- Utilisé pour le soutien entre agences
- Exemple: Shop Kampala prête à Shop Durba

#### 2. **Partenaire** (Entreprise externe)
```dart
typeBeneficiaire: 'partenaire'
```
- Crédit accordé à un partenaire commercial
- Exemple: Opérateur Mobile Money, Fournisseur

#### 3. **Autre**
```dart
typeBeneficiaire: 'autre'
```
- Crédit accordé à toute autre entité
- Flexibilité pour cas spéciaux

---

### Impact Financier

#### Lors de l'Accord du Crédit

```
État AVANT:
- Solde Virtuel SIM: 10,000 USD
- Cash Disponible: 5,000 USD

ACCORD CRÉDIT 3,000 USD:
- Solde Virtuel SIM: 7,000 USD (-3,000)
- Cash Disponible: 5,000 USD (inchangé)

⚠️ IMPORTANT: Le cash ne bouge PAS lors de l'accord!
   Seul le solde virtuel diminue.
```

#### Lors du Paiement

```
État AVANT PAIEMENT:
- Solde Virtuel SIM: 7,000 USD
- Cash Disponible: 5,000 USD
- Crédit En Cours: 3,000 USD

PAIEMENT REÇU 3,000 USD:
- Solde Virtuel SIM: 7,000 USD (inchangé)
- Cash Disponible: 8,000 USD (+3,000)
- Crédit En Cours: 0 USD (soldé)

✅ Le cash augmente lors du paiement!
```

---

### Calcul du Solde Virtuel Disponible

```dart
Solde Virtuel Disponible = 
    Σ (Captures Virtuelles Validées)
  - Σ (Crédits Inter-Shop Non Annulés)
  - Σ (Retraits Virtuels)
```

**Exemple:**
```
Captures virtuelles: +50,000 USD
Crédits accordés:    -15,000 USD
Retraits virtuels:   -10,000 USD
─────────────────────────────────
Disponible:          25,000 USD
```

**Règle Critique:**
> ⚠️ Un shop ne peut PAS accorder un crédit si:
> `Montant Crédit > Solde Virtuel Disponible`

---

### Statuts d'un Crédit

#### 1. **Accordé** (`accorde`)
```
Crédit vient d'être créé
- Solde virtuel diminué
- Aucun paiement reçu
- Montant restant = Montant total
```

#### 2. **Partiellement Payé** (`partiellementPaye`)
```
Paiement(s) partiel(s) reçu(s)
- Une partie du montant payée
- Montant restant > 0
- Exemple: 3,000 USD accordés, 1,000 USD payés
```

#### 3. **Payé** (`paye`)
```
Crédit entièrement remboursé
- Montant restant = 0
- Cash totalement reçu
- Date de paiement enregistrée
```

#### 4. **Annulé** (`annule`)
```
Crédit annulé (erreur, accord révoqué)
- Solde virtuel restauré
- Aucun impact sur le cash
- Impossible d'annuler un crédit payé
```

#### 5. **En Retard** (`enRetard`)
```
Date d'échéance dépassée
- Alerte automatique
- Crédit toujours actif
- Nécessite action de recouvrement
```

---

### Informations Enregistrées

```dart
CreditVirtuelModel {
  // Identification
  reference: 'CRED-240125-001',  // Unique
  montantCredit: 5000.0,
  devise: 'USD',
  
  // Bénéficiaire
  beneficiaireNom: 'Shop Durba',
  beneficiaireTelephone: '+243123456789',
  beneficiaireAdresse: 'Avenue Mobutu',
  typeBeneficiaire: 'shop',
  
  // Shop émetteur
  shopId: 1,
  shopDesignation: 'Shop Kampala',
  simNumero: '+243970123456',  // SIM utilisée
  
  // Agent
  agentId: 10,
  agentUsername: 'agent_john',
  
  // Dates
  dateSortie: DateTime(2024, 01, 25),
  dateEcheance: DateTime(2024, 02, 25), // 1 mois
  datePaiement: null,  // Sera rempli au paiement
  
  // Paiement
  montantPaye: 0.0,
  montantRestant: 5000.0,
  modePaiement: null,
  referencePaiement: null,
  
  // Statut
  statut: CreditVirtuelStatus.accorde,
  notes: 'Crédit pour approvisionnement'
}
```

---

### Opérations Disponibles

#### 1. **Accorder un Crédit**

```dart
await creditVirtuelService.accorderCredit(
  reference: 'CRED-${DateTime.now()}',
  montantCredit: 5000.0,
  devise: 'USD',
  beneficiaireNom: 'Shop Partenaire',
  beneficiaireTelephone: '+243123456789',
  typeBeneficiaire: 'shop',
  simNumero: '+243970123456',
  shopId: currentShopId,
  agentId: currentAgentId,
  dateEcheance: DateTime.now().add(Duration(days: 30)),
  notes: 'Crédit pour réapprovisionnement',
);
```

**Vérifications automatiques:**
- ✅ Référence unique
- ✅ SIM existe et appartient au shop
- ✅ Solde virtuel suffisant
- ✅ Montant > 0

#### 2. **Enregistrer un Paiement**

```dart
await creditVirtuelService.enregistrerPaiement(
  creditId: 123,
  montantPaiement: 2000.0,  // Paiement partiel
  modePaiement: 'cash',
  referencePaiement: 'PAY-20240125-001',
  agentId: currentAgentId,
);
```

**Comportement:**
- Paiement partiel: Statut → `partiellementPaye`
- Paiement total: Statut → `paye`
- Cash du shop augmente immédiatement

#### 3. **Annuler un Crédit**

```dart
await creditVirtuelService.annulerCredit(
  creditId: 123,
  agentId: currentAgentId,
  motifAnnulation: 'Erreur de saisie',
);
```

**Restrictions:**
- ❌ Impossible d'annuler un crédit déjà payé
- ✅ Solde virtuel restauré si annulé

---

### Statistiques et Rapports

```dart
final stats = await creditVirtuelService.getStatistiques(
  shopId: 1,
  dateDebut: DateTime(2024, 01, 01),
  dateFin: DateTime(2024, 01, 31),
);

// Résultat:
{
  'nombre_credits': 15,
  'total_accorde': 75000.0,
  'total_paye': 45000.0,
  'total_en_attente': 25000.0,
  'total_en_retard': 5000.0,
  'nombre_payes': 8,
  'nombre_en_attente': 5,
  'nombre_en_retard': 2,
  'taux_recouvrement': 60.0,  // %
}
```

---

### Alertes et Notifications

#### Crédit En Retard

```dart
if (credit.estEnRetard) {
  // Alerte automatique
  print('⚠️ Crédit en retard: ${credit.reference}');
  print('   Bénéficiaire: ${credit.beneficiaireNom}');
  print('   Montant restant: ${credit.montantRestant}');
  print('   Échéance dépassée de: ${DateTime.now().difference(credit.dateEcheance!).inDays} jours');
}
```

---

### Synchronisation

Les crédits inter-shop sont **synchronisés automatiquement**:

1. **Création locale** → File de synchronisation
2. **Sync vers serveur** → Upload
3. **Mise à jour serveur** → Download
4. **Notification autres shops** → Si concernés

```dart
// Synchronisation manuelle
await creditVirtuelService.syncNow();
```

---

### Cas d'Usage Typiques

#### Scénario 1: Soutien Entre Shops

```
Situation:
- Shop Kampala a beaucoup de solde virtuel (50,000 USD)
- Shop Durba manque de liquidité virtuelle

Solution:
1. Shop Kampala accorde crédit 10,000 USD à Shop Durba
2. Shop Durba utilise ce crédit pour opérations
3. Plus tard, Shop Durba rembourse en cash
4. Shop Kampala récupère liquidité cash

Avantage: 
✅ Solidarité entre agences
✅ Optimisation des ressources virtuelles
✅ Traçabilité complète
```

#### Scénario 2: Crédit Partenaire

```
Situation:
- Shop a besoin de marchandises d'un fournisseur
- Fournisseur accepte crédit virtuel

Solution:
1. Shop accorde crédit 5,000 USD au fournisseur
2. Fournisseur livre les marchandises
3. Shop paie en cash à échéance convenue
4. Crédit soldé

Avantage:
✅ Facilite les transactions commerciales
✅ Délai de paiement possible
✅ Relation win-win
```

---

### Règles Métier Critiques

#### ⚠️ RÈGLES ABSOLUES

1. **Solde Virtuel Obligatoire**
   ```
   Crédit Accordé ≤ Solde Virtuel Disponible
   ```

2. **Référence Unique**
   ```
   Chaque crédit doit avoir une référence UNIQUE
   Format suggéré: CRED-YYMMDD-XXX
   ```

3. **Impact Virtuel Immédiat**
   ```
   Accord crédit → Solde virtuel diminue IMMÉDIATEMENT
   Paiement → Cash augmente IMMÉDIATEMENT
   ```

4. **Pas d'Annulation Après Paiement**
   ```
   IF (montantPaye > 0) THEN Annulation = IMPOSSIBLE
   ```

5. **Traçabilité Totale**
   ```
   Chaque opération enregistre:
   - Agent qui fait l'action
   - Date et heure exacte
   - Modifications (lastModifiedAt, lastModifiedBy)
   ```

6. **Synchronisation Obligatoire**
   ```
   Tous les crédits DOIVENT être synchronisés avec le serveur
   État: isSynced = false → Upload pending
   ```

---

### Différence avec Autres Opérations

| Opération | Impact Immédiat | Type |
|-----------|----------------|------|
| **FLOT Physique** | Cash diminue/augmente | Mouvement cash réel |
| **FLOT Administratif** | Crée dette, pas de cash | Dette comptable |
| **Crédit Inter-Shop** | Virtuel diminue → Cash augmente plus tard | Crédit avec échéance |
| **Transfert National** | Cash augmente immédiatement | Transaction instantanée |

---

### Formules de Calcul

#### Solde Virtuel Disponible
```dart
double soldeVirtuelDisponible = 
    Σ(captures_validees.montantVirtuel) - 
    Σ(credits_non_annules.montantCredit) - 
    Σ(retraits_virtuels.montant);
```

#### Montant Restant d'un Crédit
```dart
double montantRestant = 
    credit.montantCredit - credit.montantPaye;
```

#### Taux de Recouvrement
```dart
double tauxRecouvrement = 
    (totalPaye / totalAccorde) * 100;
```

#### Crédit En Retard
```dart
bool estEnRetard = 
    credit.dateEcheance != null &&
    DateTime.now().isAfter(credit.dateEcheance!) &&
    credit.montantRestant > 0;
```

---

### Sécurité et Validation

#### Validations Automatiques

```dart
// Avant accord crédit
if (montantCredit <= 0) {
  throw 'Montant doit être positif';
}

if (montantCredit > soldeVirtuelDisponible) {
  throw 'Solde virtuel insuffisant';
}

if (reference.isEmpty) {
  throw 'Référence obligatoire';
}

if (await creditExists(reference)) {
  throw 'Référence déjà utilisée';
}

// Avant paiement
if (montantPaiement <= 0) {
  throw 'Montant paiement doit être positif';
}

if (montantPaye + montantPaiement > montantCredit) {
  throw 'Paiement dépasse le montant du crédit';
}

if (credit.statut == 'annule') {
  throw 'Crédit annulé, paiement impossible';
}
```

---

### Rapport Crédits Inter-Shop

Le rapport affiche:

```
📊 CRÉDITS INTER-SHOP
════════════════════════════════

💰 STATISTIQUES GLOBALES
   Nombre total:        25 crédits
   Montant accordé:     125,000 USD
   Montant payé:        75,000 USD
   Montant en attente:  45,000 USD
   Montant en retard:   5,000 USD
   Taux recouvrement:   60%

✅ CRÉDITS PAYÉS (15)
   [Liste des crédits soldés]

⏳ EN ATTENTE (8)
   [Liste des crédits en cours]

⚠️ EN RETARD (2)
   CRED-240115-001  Shop Durba    3,000 USD  (15 jours retard)
   CRED-240120-002  Partenaire X  2,000 USD  (8 jours retard)

❌ ANNULÉS (0)
```

---

### Intégration avec Autres Modules

#### Avec Gestion SIM
```dart
// Le crédit utilise le solde d'une SIM spécifique
final sim = await SimService.instance.getSimByNumero(simNumero);
if (sim == null) throw 'SIM non trouvée';
```

#### Avec Rapport de Clôture
```dart
// Les paiements augmentent le cash disponible
// Pris en compte dans la clôture journalière
cashDisponible += paiementsCreditsDuJour;
```

#### Avec Dashboard Admin
```dart
// Admin voit tous les crédits inter-shop
// Peut suivre le recouvrement global
// Détecte les crédits en retard
```

---

### Best Practices

#### ✅ À FAIRE

1. **Définir échéance claire**
   ```dart
   dateEcheance: DateTime.now().add(Duration(days: 30))
   ```

2. **Documenter le crédit**
   ```dart
   notes: 'Crédit pour réapprovisionnement stocks Mobile Money'
   ```

3. **Vérifier solde avant accord**
   ```dart
   final disponible = await calculateSoldeVirtuelDisponible(simNumero);
   if (disponible < montantDemande) { /* Refuser */ }
   ```

4. **Suivre les crédits en retard**
   ```dart
   final enRetard = creditVirtuelService.getCreditsEnRetard();
   // Relancer le bénéficiaire
   ```

#### ❌ À ÉVITER

1. **Accorder crédit sans vérifier solde**
   - Risque: Solde virtuel négatif

2. **Oublier date d'échéance**
   - Risque: Pas de suivi des retards

3. **Références duplicates**
   - Risque: Conflits de synchronisation

4. **Annuler crédit déjà payé**
   - Risque: Incohérence comptable

---

## 💱 GESTION DES DEVISES

### Devises Supportées

- **USD** (Dollar Américain) - devise principale
- **CDF** (Franc Congolais)
- **EUR** (Euro)

### Taux de Change

- Taux configurables par l'admin
- Conversion automatique lors des transferts internationaux
- Historique des taux de change

---

## 📝 COMPTABILITÉ SPÉCIALE

### Comptes Spéciaux

1. **Compte FRAIS**
   - Enregistrement des frais versés aux opérateurs
   - Suivi des dépenses d'exploitation

2. **Compte DÉPENSE**
   - Autres dépenses du shop
   - Catégorisation des sorties de cash

### Règlement de Dettes Triangulaires

Système de compensation des dettes entre 3 shops ou plus:

```
Shop A doit 100$ à Shop B
Shop B doit 80$ à Shop C
Shop C doit 50$ à Shop A

Solution: Compensation triangulaire
→ Réduction des dettes réelles
→ Moins de mouvements physiques de cash
```

---

## 🔐 SÉCURITÉ ET AUDIT

### Traçabilité

Chaque opération enregistre:
- Date et heure précise
- Agent qui a fait l'opération
- Modifications ultérieures (lastModifiedAt, lastModifiedBy)
- Statut de synchronisation

### Logs

- Historique complet des actions
- Détection des anomalies
- Rapports d'audit pour l'admin

---

## 📱 FONCTIONNALITÉS TECHNIQUES

### Mode Offline

- Toutes les opérations fonctionnent sans internet
- Données stockées localement en SQLite
- Synchronisation automatique au retour de la connexion

### Impression

- Reçus thermiques via Bluetooth
- Support des imprimantes POS Android
- Export PDF des rapports

### Billetage

- Comptage détaillé des billets lors de la clôture
- Par coupure (1$, 5$, 10$, 20$, 50$, 100$)
- Détection automatique des écarts

---

## 🌐 INTERNATIONALISATION

### Langues Supportées

- **Français** (FR) - Langue par défaut
- **Anglais** (EN)

### Changement de Langue

- Dynamique sans redémarrage
- Sauvegarde de la préférence utilisateur
- Tous les textes traduits

---

## 🎨 INTERFACE UTILISATEUR

### Design

- **Responsive**: Adapté mobile, tablette, desktop
- **Material Design 3**: Interface moderne
- **Thème Rouge UCASH**: Couleur primaire #DC2626
- **Mode Clair uniquement**: Pas de mode sombre

### Navigation

- **Dashboard**: Vue d'ensemble
- **Opérations**: Gestion des transactions
- **Clients**: Gestion de la clientèle
- **Rapports**: Statistiques et analyses
- **Paramètres**: Configuration

---

## 📊 INDICATEURS DE PERFORMANCE (KPI)

### Pour l'Agent

- Cash disponible en temps réel
- Commissions gagnées du jour
- Nombre d'opérations traitées
- Écarts de caisse

### Pour l'Admin

- Cash total de l'entreprise
- Performance par shop
- Dettes inter-shops à régler
- Volume d'opérations global
- Rentabilité par type d'opération

---

## 🚀 WORKFLOW TYPIQUE

### Journée d'un Agent

1. **Matin**
   - Ouverture de session
   - Vérification du cash initial

2. **Pendant la Journée**
   - Traitement des opérations clients
   - Validation des transferts entrants
   - Envoi des FLOT si besoin

3. **Soir**
   - Clôture de caisse (cash global)
   - Clôture virtuelle (par SIM)
   - Comptage du billetage
   - Synchronisation finale

---

## 🏆 RÈGLES MÉTIER CRITIQUES

### ⚠️ RÈGLES ABSOLUES

1. **Cash Disponible**: Ne peut JAMAIS être négatif
2. **FLOT Administratif**: N'impacte PAS le cash immédiatement
3. **Commissions Admin**: Toujours = 0
4. **Sync Obligatoire**: Avant clôture de caisse
5. **Validation Admin**: Requise pour suppressions sensibles
6. **Agent Limité**: Accès UNIQUEMENT à son shop
7. **Client Admin**: shopId = NULL, accessible par tous
8. **Code Opération**: Unique et obligatoire (format: YYMMDDHHMMSSXXX)

---

## 📞 SUPPORT ET MAINTENANCE

### Logs de Débogage

- Système de logging complet
- Export des logs pour support technique
- Détection automatique des erreurs critiques

### Mises à Jour

- Application auto-updatable
- Synchronisation des schémas de base de données
- Migration automatique des données

---

## 🎯 OBJECTIFS BUSINESS

1. **Traçabilité Complète**: Chaque centime est tracé
2. **Zéro Perte**: Détection immédiate des écarts
3. **Multi-Shops**: Gestion centralisée de plusieurs agences
4. **Temps Réel**: Données à jour instantanément
5. **Offline-First**: Pas de dépendance internet permanente
6. **Conformité**: Respect des réglementations financières

---

## 📚 GLOSSAIRE

- **Shop**: Point de vente, agence
- **Agent**: Employé d'un shop
- **FLOT**: Mouvement de liquidité entre shops
- **Cash-In**: Dépôt d'argent (Mobile Money)
- **Cash-Out**: Retrait d'argent (Mobile Money)
- **SIM**: Carte SIM Mobile Money (Airtel, Vodacom, Orange)
- **Clôture**: Fermeture comptable de fin de journée
- **Billetage**: Comptage détaillé des billets par coupure
- **Sync**: Synchronisation entre local et serveur
- **Dette Bilatérale**: Dette entre deux shops
- **Dette Triangulaire**: Dette impliquant 3 shops ou plus

---

## 🔗 ARCHITECTURE TECHNIQUE

### Stack Technologique

**Frontend:**
- Flutter/Dart (iOS, Android, Web)
- Provider (State Management)
- SQLite (Base de données locale)

**Backend:**
- PHP 7.4+
- MySQL 8.0+
- REST API

**Synchronisation:**
- HTTP/HTTPS
- JSON
- Retry automatique avec backoff exponentiel

---

## ✅ CONCLUSION

UCASH est une solution complète de gestion financière pour agences de transfert d'argent, combinant:

- ✅ **Simplicité d'utilisation** pour les agents
- ✅ **Puissance de gestion** pour les administrateurs
- ✅ **Fiabilité** avec traçabilité totale
- ✅ **Flexibilité** offline et multi-shops
- ✅ **Sécurité** avec authentification et audit
- ✅ **Performance** temps réel avec synchronisation robuste

---

**Version**: 1.0.0  
**Dernière mise à jour**: Janvier 2026  
**Auteur**: Équipe UCASH
