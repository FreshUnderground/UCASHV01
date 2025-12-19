# 🏗️ Architecture du Système de Gestion du Personnel

## 📊 Diagramme de Structure

```mermaid
graph TB
    A[Dashboard Admin] --> B[Gestion Personnel]
    A --> C[Salaires Mensuels]
    A --> D[Avances & Crédits]
    A --> E[Rapports]
    
    B --> F[PersonnelService]
    C --> G[SalaireService]
    D --> H[AvanceService]
    D --> I[CreditService]
    E --> J[ReportService]
    
    F --> K[LocalDB]
    G --> K
    H --> K
    I --> K
    J --> K
    
    K --> L[SyncService]
    L --> M[API Server]
    M --> N[MySQL Database]
    
    N --> O[personnel]
    N --> P[salaires]
    N --> Q[avances_personnel]
    N --> R[credits_personnel]
    N --> S[fiches_paie]
```

## 🔄 Flux de Données - Génération Salaire

```mermaid
graph LR
    A[Sélectionner Mois/Année] --> B[Charger Personnel Actif]
    B --> C[Pour chaque employé]
    C --> D[Récupérer Salaire Base + Primes]
    D --> E[Calculer Avances à déduire]
    E --> F[Calculer Crédits à déduire]
    F --> G[Calculer Impôts + CNSS]
    G --> H[Créer SalaireModel]
    H --> I{Trigger DB}
    I --> J[Calcul Auto Brut/Net]
    J --> K[Sauvegarder Salaire]
    K --> L[Générer Fiche de Paie]
```

## 💰 Flux de Remboursement

```mermaid
graph TB
    A[Générer Salaire Mensuel] --> B{Avances en cours?}
    B -->|Oui| C[Calculer déduction mensuelle]
    B -->|Non| E
    C --> D[Déduire du salaire]
    D --> E{Crédits en cours?}
    E -->|Oui| F[Calculer mensualité]
    E -->|Non| H
    F --> G[Déduire du salaire]
    G --> H[Calculer Net Final]
    H --> I[Mettre à jour avances/crédits]
    I --> J[Sauvegarder]
```

## 📱 Architecture UI

```mermaid
graph TB
    A[AppBar - Navigation] --> B[Sidebar Menu]
    B --> C[Personnel Icon]
    B --> D[Salaires Icon]
    B --> E[Rapports Icon]
    
    C --> F[Liste Personnel Widget]
    F --> G[Formulaire Add/Edit]
    F --> H[Détails Personnel]
    
    D --> I[Calendrier Mensuel]
    I --> J[Liste Salaires]
    J --> K[Détail Salaire]
    
    E --> L[Sélecteur Période]
    L --> M[Rapport Mensuel PDF]
    L --> N[Rapport Annuel Excel]
```

## 🗃️ Structure de la Base de Données

```mermaid
erDiagram
    PERSONNEL ||--o{ SALAIRES : "recoit"
    PERSONNEL ||--o{ AVANCES : "obtient"
    PERSONNEL ||--o{ CREDITS : "obtient"
    SALAIRES ||--|| FICHES_PAIE : "genere"
    CREDITS ||--o{ REMBOURSEMENTS : "a"
    SHOPS ||--o{ PERSONNEL : "emploie"
    
    PERSONNEL {
        int id PK
        string matricule UK
        string nom
        string prenom
        string poste
        decimal salaire_base
        string statut
        int shop_id FK
    }
    
    SALAIRES {
        int id PK
        string reference UK
        int personnel_id FK
        int mois
        int annee
        decimal salaire_brut
        decimal total_deductions
        decimal salaire_net
        string statut
    }
    
    AVANCES {
        int id PK
        string reference UK
        int personnel_id FK
        decimal montant
        decimal montant_restant
        string statut
    }
    
    CREDITS {
        int id PK
        string reference UK
        int personnel_id FK
        decimal montant_credit
        decimal taux_interet
        decimal mensualite
        string statut
    }
```

## 🔐 Gestion des Permissions

```mermaid
graph TB
    A[Utilisateur] --> B{Rôle?}
    B -->|ADMIN| C[Accès Complet]
    B -->|COMPTABLE| D[Accès Limité]
    B -->|AGENT| E[Consultation Seule]
    
    C --> F[CRUD Personnel]
    C --> G[Générer Salaires]
    C --> H[Accorder Avances/Crédits]
    C --> I[Tous Rapports]
    
    D --> J[Voir Personnel]
    D --> K[Générer Salaires]
    D --> L[Rapports Financiers]
    
    E --> M[Voir Sa Fiche]
    E --> N[Voir Ses Salaires]
    E --> O[Voir Ses Avances/Crédits]
```

## 📊 Modèle de Données - Relations

```
Personnel (1) ──────────────► (N) Salaires
    │                              │
    │                              │
    │                              ▼
    │                         Fiches de Paie (1:1)
    │
    ├─────────────► (N) Avances
    │                    │
    │                    └─► Déductions Mensuelles
    │
    └─────────────► (N) Crédits
                         │
                         └─► (N) Remboursements
```

## 🔄 Cycle de Vie d'un Salaire

```mermaid
stateDiagram-v2
    [*] --> Brouillon: Création
    Brouillon --> EnAttente: Validation
    EnAttente --> Partiel: Paiement Partiel
    EnAttente --> Paye: Paiement Complet
    Partiel --> Paye: Solde Payé
    EnAttente --> Annule: Annulation
    Partiel --> Annule: Annulation
    Paye --> [*]
    Annule --> [*]
```

## 🔄 Cycle de Vie d'une Avance

```mermaid
stateDiagram-v2
    [*] --> EnCours: Octroi
    EnCours --> EnCours: Remboursement Partiel
    EnCours --> Rembourse: Remboursement Complet
    EnCours --> Annule: Annulation
    Rembourse --> [*]
    Annule --> [*]
```

## 📁 Structure des Fichiers du Projet

```
UCASHV01/
│
├── database/
│   └── create_personnel_management_tables.sql    ✅ Créé
│
├── lib/
│   ├── models/
│   │   ├── personnel_model.dart                  ✅ Créé
│   │   ├── salaire_model.dart                    ✅ Créé
│   │   ├── avance_personnel_model.dart           ✅ Créé
│   │   ├── credit_personnel_model.dart           ✅ Créé
│   │   └── fiche_paie_model.dart                 ✅ Créé
│   │
│   ├── services/
│   │   ├── personnel_service.dart                ⏳ À créer
│   │   ├── salaire_service.dart                  ⏳ À créer
│   │   ├── avance_service.dart                   ⏳ À créer
│   │   ├── credit_service.dart                   ⏳ À créer
│   │   └── fiche_paie_service.dart               ⏳ À créer
│   │
│   └── widgets/
│       ├── gestion_personnel_widget.dart         ⏳ À créer
│       ├── salaires_mensuels_widget.dart         ⏳ À créer
│       ├── avances_credits_widget.dart           ⏳ À créer
│       └── rapport_paiements_widget.dart         ⏳ À créer
│
├── server/
│   └── api/sync/
│       ├── personnel/                            ⏳ À créer
│       │   ├── upload.php
│       │   └── changes.php
│       ├── salaires/                             ⏳ À créer
│       ├── avances/                              ⏳ À créer
│       └── credits/                              ⏳ À créer
│
└── Documentation/
    ├── GESTION_PERSONNEL_GUIDE.md                ✅ Créé
    ├── PERSONNEL_MANAGEMENT_SUMMARY.md           ✅ Créé
    └── PERSONNEL_ARCHITECTURE.md                 ✅ Créé
```

## 🎯 Points d'Entrée de l'Application

### 1. Dashboard Admin

```dart
// Dans dashboard_admin.dart

ListTile(
  leading: Icon(Icons.people, color: Colors.blue),
  title: Text('Gestion du Personnel'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestionPersonnelWidget(),
      ),
    );
  },
),
```

### 2. Menu Salaires

```dart
ListTile(
  leading: Icon(Icons.attach_money, color: Colors.green),
  title: Text('Salaires Mensuels'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalairesMensuelsWidget(),
      ),
    );
  },
),
```

### 3. Menu Rapports

```dart
ListTile(
  leading: Icon(Icons.assessment, color: Colors.orange),
  title: Text('Rapports Personnel'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RapportPaiementsWidget(),
      ),
    );
  },
),
```

## 🔧 Technologies Utilisées

| Composant | Technologie |
|-----------|-------------|
| Frontend | Flutter/Dart |
| Backend | PHP 7.4+ |
| Base de données | MySQL 8.0 |
| PDF Generation | pdf package (Dart) |
| Synchronisation | REST API |
| Stockage local | sqflite (LocalDB) |
| UI Framework | Material Design |

## 📈 Performance & Optimisation

### Index Créés

```sql
-- Personnel
CREATE INDEX idx_personnel_actif ON personnel(statut, shop_id);
CREATE INDEX idx_matricule ON personnel(matricule);

-- Salaires
CREATE INDEX idx_salaires_periode_statut ON salaires(annee, mois, statut);
CREATE INDEX idx_personnel_id ON salaires(personnel_id);

-- Avances
CREATE INDEX idx_avances_statut_personnel ON avances_personnel(statut, personnel_id);

-- Crédits
CREATE INDEX idx_credits_statut_personnel ON credits_personnel(statut, personnel_id);
```

### Triggers pour Performance

- Calcul automatique du salaire brut/net (évite calculs client-side)
- Mise à jour auto des montants restants
- Détection auto des retards de crédit

## 🔒 Sécurité

### Validation des Données

- ✅ Matricule unique obligatoire
- ✅ Salaire base > 0
- ✅ Dates cohérentes (embauche < fin contrat)
- ✅ Montants > 0 pour avances/crédits
- ✅ Taux intérêt >= 0

### Contraintes BD

- ✅ Foreign Keys (CASCADE/SET NULL)
- ✅ Unique Keys (matricule, référence)
- ✅ NOT NULL sur champs critiques
- ✅ DEFAULT values appropriées

## 🎨 Palette de Couleurs

```dart
// Statuts Personnel
static const Color actif = Color(0xFF4CAF50);      // Vert
static const Color suspendu = Color(0xFFFF9800);   // Orange
static const Color demissionne = Color(0xFF9E9E9E); // Gris

// Statuts Paiement
static const Color enAttente = Color(0xFFFF9800);  // Orange
static const Color paye = Color(0xFF2196F3);       // Bleu
static const Color partiel = Color(0xFFFFC107);    // Jaune
static const Color annule = Color(0xFFF44336);     // Rouge

// Statuts Crédit
static const Color enCours = Color(0xFF2196F3);    // Bleu
static const Color rembourse = Color(0xFF4CAF50);  // Vert
static const Color enRetard = Color(0xFFF44336);   // Rouge
```

## 📊 Métriques & KPIs

### Indicateurs Principaux

1. **Masse Salariale Mensuelle**: Total des salaires nets
2. **Taux de Paiement**: % de salaires payés à temps
3. **Avances en Cours**: Total des avances non remboursées
4. **Crédits en Retard**: Nombre et montant des crédits en retard
5. **Turnover**: Taux de rotation du personnel

### Rapports Générés

1. Rapport mensuel des paiements
2. Rapport annuel de la masse salariale
3. Rapport individuel par employé
4. Rapport des avances et crédits
5. Rapport de trésorerie RH

---

**Architecture créée le**: 17 Décembre 2024  
**Version**: 1.0  
**Projet**: UCASH V01 - Gestion du Personnel
