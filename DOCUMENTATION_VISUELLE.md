# DOCUMENTATION VISUELLE UCASH

## ARCHITECTURE SYSTÈME

```
┌─────────────────────────────────────────────────────────────────┐
│                        SYSTÈME UCASH                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │    ADMIN    │    │    AGENT    │    │   CLIENT    │         │
│  │             │    │             │    │             │         │
│  │ • Dashboard │    │ • Opérations│    │ • Consultation│       │
│  │ • Gestion   │    │ • Validations│    │ • Historique │       │
│  │ • Config    │    │ • Rapports  │    │ • Services   │       │
│  │ • Rapports  │    │ • FLOT      │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┘              │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  BASE DE DONNÉES                       │   │
│  │                                                         │   │
│  │ • Opérations      • Agents         • Clients          │   │
│  │ • Shops          • Transactions    • Rapports         │   │
│  │ • Taux           • Commissions     • Audit Trail      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   SERVEUR API                          │   │
│  │                                                         │   │
│  │ • Synchronisation  • Validation    • Backup           │   │
│  │ • Authentification • Logs          • Monitoring       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## WORKFLOW PRINCIPAL - OPÉRATION AGENT

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   CONNEXION │───▶│ VÉRIFICATION│───▶│  OPÉRATION  │───▶│   CLÔTURE   │
│    AGENT    │    │  CLÔTURES   │    │             │    │ QUOTIDIENNE │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│• Username   │    │• Clôtures   │    │• Dépôts     │    │• Récapitulatif│
│• Password   │    │  manquantes?│    │• Retraits   │    │• Soldes     │
│• Shop ID    │    │• Blocage    │    │• Transferts │    │• Validation │
│             │    │  préventif  │    │• Billetages │    │• Sync serveur│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## FLUX DE VALIDATION TRANSFERTS

```
                    TRANSFERT INTER-SHOPS
                           │
                           ▼
    ┌─────────────────────────────────────────────────────────┐
    │                SHOP SOURCE                              │
    │  ┌─────────────┐                                        │
    │  │   AGENT A   │ Initie le transfert                   │
    │  │             │ • Montant: 1000 USD                   │
    │  │             │ • Commission: 50 USD                  │
    │  │             │ • Total débité: 1050 USD              │
    │  └─────────────┘                                        │
    └─────────────────────────────────────────────────────────┘
                           │
                           ▼ (Statut: EN_ATTENTE)
    ┌─────────────────────────────────────────────────────────┐
    │              SHOP DESTINATION                           │
    │  ┌─────────────┐                                        │
    │  │   AGENT B   │ Reçoit la demande                     │
    │  │             │ • Vérifie les fonds                   │
    │  │             │ • Valide ou refuse                    │
    │  │             │ • Montant à servir: 1000 USD          │
    │  └─────────────┘                                        │
    └─────────────────────────────────────────────────────────┘
                           │
                           ▼ (Statut: VALIDEE)
    ┌─────────────────────────────────────────────────────────┐
    │                   RÉSULTAT                              │
    │                                                         │
    │  • Shop A: Dette de 1000 USD envers Shop B            │
    │  • Shop B: Créance de 1000 USD sur Shop A             │
    │  • Commission de 50 USD pour Shop A                    │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

## SYSTÈME DE DETTES INTERSHOPS

```
                    CALCUL DES POSITIONS NETTES
    
    SHOP A                    SHOP B                    SHOP C
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│             │   1000   │             │   800    │             │
│   Doit à B  │ ────────▶│  Créance A  │ ────────▶│   Doit à B  │
│             │          │             │          │             │
│   Créance C │ ◀──────── │   Doit à C  │ ◀──────── │  Créance A  │
│             │   500    │             │   300    │             │
└─────────────┘          └─────────────┘          └─────────────┘

AVANT RÈGLEMENT TRIANGULAIRE:
• Shop A doit 1000 à B, créance 500 sur C → Position nette: -500
• Shop B créance 1000 sur A, doit 800 à C → Position nette: +200  
• Shop C créance 800 sur B, doit 500 à A → Position nette: +300

APRÈS RÈGLEMENT TRIANGULAIRE:
• A paie 500 directement à C (au lieu de B puis B à C)
• Positions optimisées, flux réduits
```

## WORKFLOW CLÔTURE QUOTIDIENNE

```
                        CLÔTURE AGENT
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 VÉRIFICATIONS                           │
    │                                                         │
    │  ✓ Toutes les opérations saisies                      │
    │  ✓ Billetages équilibrés                              │
    │  ✓ Transferts en attente traités                      │
    │  ✓ Soldes virtuels réconciliés                        │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                   CALCULS                               │
    │                                                         │
    │  • Cash disponible = Solde initial + Entrées - Sorties │
    │  • Commissions générées                                 │
    │  • Frais perçus                                        │
    │  • Positions intershops                                │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 GÉNÉRATION                              │
    │                                                         │
    │  • Rapport PDF                                         │
    │  • Sauvegarde locale                                   │
    │  • Synchronisation serveur                             │
    │  • Notification admin                                  │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

## ARCHITECTURE MODULE VIRTUEL

```
                        TRANSACTIONS VIRTUELLES
                               │
                               ▼
    ┌─────────────────────────────────────────────────────────┐
    │                    OPÉRATEURS                           │
    │                                                         │
    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
    │  │   ORANGE    │  │   AIRTEL    │  │   AUTRES    │     │
    │  │             │  │             │  │             │     │
    │  │ • SIM Cards │  │ • SIM Cards │  │ • SIM Cards │     │
    │  │ • Soldes    │  │ • Soldes    │  │ • Soldes    │     │
    │  │ • Taux      │  │ • Taux      │  │ • Taux      │     │
    │  └─────────────┘  └─────────────┘  └─────────────┘     │
    └─────────────────────────────────────────────────────────┘
                               │
                               ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 TYPES D'OPÉRATIONS                     │
    │                                                         │
    │  • CAPTURES (Client → Agent)                           │
    │  • SERVICES (Agent → Client)                           │
    │  • RECHARGES (Crédit téléphonique)                    │
    │  • PAIEMENTS (Factures, services)                     │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                               │
                               ▼
    ┌─────────────────────────────────────────────────────────┐
    │                    RÉCONCILIATION                       │
    │                                                         │
    │  • Solde virtuel par SIM                              │
    │  • Cash équivalent                                     │
    │  • Écarts et ajustements                               │
    │  • Clôture par opérateur                               │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

## WORKFLOW SUPPRESSION SÉCURISÉE

```
                    DEMANDE DE SUPPRESSION
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                   ÉTAPE 1: ADMIN                       │
    │                                                         │
    │  • Identification de l'erreur                         │
    │  • Justification obligatoire                          │
    │  • Création de la demande                             │
    │  • Statut: EN_ATTENTE                                 │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 ÉTAPE 2: VALIDATION                    │
    │                                                         │
    │  • Vérification par autre admin                       │
    │  • Contrôle de cohérence                              │
    │  • Approbation/Refus                                  │
    │  • Statut: ADMIN_VALIDEE                              │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                 ÉTAPE 3: AGENT                         │
    │                                                         │
    │  • Validation finale par agent                        │
    │  • Vérification terrain                               │
    │  • Confirmation définitive                            │
    │  • Statut: AGENT_VALIDEE                              │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                ÉTAPE 4: EXÉCUTION                      │
    │                                                         │
    │  • Sauvegarde en corbeille                            │
    │  • Suppression de la base active                      │
    │  • Audit trail complet                                │
    │  • Notification des parties                           │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

## DASHBOARD ADMIN - STRUCTURE

```
    ┌─────────────────────────────────────────────────────────┐
    │                    HEADER                               │
    │  Logo UCASH | Dashboard Admin | Notifications | Profile │
    └─────────────────────────────────────────────────────────┘
    │
    ┌─────────────────────────────────────────────────────────┐
    │                 STATISTIQUES                            │
    │                                                         │
    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
    │  │   SHOPS     │ │   AGENTS    │ │ TRANSACTIONS│       │
    │  │     15      │ │     45      │ │   1,234     │       │
    │  │   Actifs    │ │   En ligne  │ │ Aujourd'hui │       │
    │  └─────────────┘ └─────────────┘ └─────────────┘       │
    │                                                         │
    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
    │  │   REVENUS   │ │   DETTES    │ │   ALERTES   │       │
    │  │  $12,500    │ │   $2,300    │ │     3       │       │
    │  │ Ce mois     │ │ Intershops  │ │ Critiques   │       │
    │  └─────────────┘ └─────────────┘ └─────────────┘       │
    └─────────────────────────────────────────────────────────┘
    │
    ┌─────────────────────────────────────────────────────────┐
    │                ACTIONS RAPIDES                          │
    │                                                         │
    │  [Créer Shop]  [Ajouter Agent]  [Voir Rapports]       │
    │  [Config Taux] [Sync Données]   [Audit Trail]         │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
    │
    ┌─────────────────────────────────────────────────────────┐
    │                  GRAPHIQUES                             │
    │                                                         │
    │  Évolution des transactions │ Performance par shop      │
    │  ┌─────────────────────────┐ │ ┌─────────────────────┐ │
    │  │        📈              │ │ │       📊           │ │
    │  │                        │ │ │                    │ │
    │  └─────────────────────────┘ │ └─────────────────────┘ │
    └─────────────────────────────────────────────────────────┘
```

## NAVIGATION AGENT - STRUCTURE

```
    ┌─────────────────────────────────────────────────────────┐
    │                   SIDEBAR                               │
    │                                                         │
    │  📊 Opérations          [Badge: Clôture requise]       │
    │  ✅ Validations         [Badge: 5 en attente]          │
    │  📈 Rapports                                            │
    │  🚚 FLOT               [Badge: 2 reçus]                │
    │  💰 Frais                                               │
    │  📱 VIRTUEL                                             │
    │  🔄 Dettes Intershop                                    │
    │  ⚙️ Règlements                                          │
    │  🗑️ Suppressions                                        │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

## FLUX DE DONNÉES - SYNCHRONISATION

```
                        SYNCHRONISATION
    
    CLIENT (Flutter)                    SERVEUR (PHP/MySQL)
    ┌─────────────────┐                ┌─────────────────┐
    │                 │   Upload       │                 │
    │  Base Locale    │ ──────────────▶│   Base Serveur  │
    │  (SQLite)       │                │   (MySQL)       │
    │                 │   Download     │                 │
    │                 │ ◀──────────────│                 │
    └─────────────────┘                └─────────────────┘
            │                                    │
            ▼                                    ▼
    ┌─────────────────┐                ┌─────────────────┐
    │   OPÉRATIONS    │                │   VALIDATION    │
    │                 │                │                 │
    │ • Créer         │                │ • Vérifier      │
    │ • Modifier      │                │ • Valider       │
    │ • Supprimer     │                │ • Synchroniser  │
    │ • Consulter     │                │ • Sauvegarder   │
    │                 │                │                 │
    └─────────────────┘                └─────────────────┘
```

## SÉCURITÉ ET AUDIT

```
                        AUDIT TRAIL
    
    ┌─────────────────────────────────────────────────────────┐
    │                   ÉVÉNEMENT                             │
    │                                                         │
    │  • Qui: Agent/Admin ID                                 │
    │  • Quoi: Action effectuée                              │
    │  • Quand: Timestamp précis                             │
    │  • Où: Shop/Module concerné                            │
    │  • Comment: Détails techniques                         │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                  STOCKAGE                               │
    │                                                         │
    │  • Base de données chiffrée                            │
    │  • Backup automatique                                  │
    │  • Rétention configurable                             │
    │  • Accès restreint                                    │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                  ANALYSE                                │
    │                                                         │
    │  • Détection d'anomalies                              │
    │  • Rapports de conformité                             │
    │  • Alertes de sécurité                                │
    │  • Statistiques d'usage                               │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```
