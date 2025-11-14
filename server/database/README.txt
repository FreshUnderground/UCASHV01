================================================================================
BASE DE DONNÉES UCASH v2.0 - SUPPORT MULTI-DEVISES
================================================================================

CONTENU DU DOSSIER
================================================================================

1. sync_tables.sql
   - Script principal de création des tables
   - Version 2.0 avec support multi-devises (USD, CDF, UGX)
   - Inclut triggers, vues et procédures stockées
   - À utiliser pour une NOUVELLE installation

2. migration_multidevises.sql
   - Script de migration depuis l'ancienne structure
   - Convertit devise → devise_source/devise_cible
   - Ajoute les colonnes multi-devises aux shops
   - Insère les taux de change par défaut
   - À utiliser pour MIGRER une base existante

3. guide_installation.sql
   - Guide complet d'installation et configuration
   - Exemples de requêtes utiles
   - Fonctions de conversion de devises
   - Commandes de maintenance
   - Documentation et dépannage

================================================================================
INSTALLATION RAPIDE
================================================================================

NOUVELLE BASE DE DONNÉES:
--------------------------
1. Créer la base :
   mysql -u root -p
   CREATE DATABASE ucash CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   USE ucash;

2. Exécuter le script principal :
   SOURCE c:/laragon1/www/UCASHV01/server/database/sync_tables.sql;

3. Insérer les données initiales :
   Consulter guide_installation.sql pour les exemples


MIGRATION BASE EXISTANTE:
--------------------------
1. SAUVEGARDER D'ABORD !
   mysqldump -u root -p ucash > backup_ucash_20251108.sql

2. Exécuter la migration :
   mysql -u root -p ucash
   SOURCE c:/laragon1/www/UCASHV01/server/database/migration_multidevises.sql;

3. Vérifier les résultats :
   Le script affiche automatiquement les statistiques

================================================================================
CHANGEMENTS PRINCIPAUX v2.0
================================================================================

TABLE TAUX (Ancienne structure):
---------------------------------
- devise VARCHAR(10)           → Devise unique (USD, CDF, etc.)
- type ENUM(...)               → Type de taux
- taux DECIMAL(10,4)          → Valeur du taux

TABLE TAUX (Nouvelle structure):
---------------------------------
- devise_source VARCHAR(10)    → Devise de départ (ex: USD)
- devise_cible VARCHAR(10)     → Devise d'arrivée (ex: CDF)
- taux DECIMAL(10,4)          → Taux de conversion
- type ENUM(...)              → ACHAT, VENTE, MOYEN
- date_effet TIMESTAMP        → Date de validité
- est_actif BOOLEAN           → Actif ou non

Exemple: 1 USD = 2500 CDF
  devise_source: 'USD'
  devise_cible: 'CDF'
  taux: 2500.00

TABLE SHOPS (Ajouts):
---------------------
+ devise_principale              → USD par défaut
+ devise_secondaire              → CDF, UGX ou NULL
+ capital_actuel_devise2         → Capital total en devise 2
+ capital_cash_devise2           → Cash en devise 2
+ capital_airtel_money_devise2   → Airtel Money en devise 2
+ capital_mpesa_devise2          → M-Pesa en devise 2
+ capital_orange_money_devise2   → Orange Money en devise 2

TABLE OPERATIONS (Ajouts):
--------------------------
+ devise VARCHAR(10)            → Devise de l'opération (USD, CDF, UGX)

================================================================================
CONFIGURATIONS SUPPORTÉES
================================================================================

1. Shop mono-devise (USD uniquement):
   devise_principale = 'USD'
   devise_secondaire = NULL

2. Shop RDC (USD + CDF):
   devise_principale = 'USD'
   devise_secondaire = 'CDF'

3. Shop Ouganda (USD + UGX):
   devise_principale = 'USD'
   devise_secondaire = 'UGX'

================================================================================
TAUX DE CHANGE PAR DÉFAUT
================================================================================

USD → CDF:
  - Achat:  2500.00 CDF pour 1 USD
  - Vente:  2550.00 CDF pour 1 USD
  - Moyen:  2525.00 CDF pour 1 USD

USD → UGX:
  - Achat:  3650.00 UGX pour 1 USD
  - Vente:  3750.00 UGX pour 1 USD
  - Moyen:  3700.00 UGX pour 1 USD

CDF ↔ UGX:
  - Taux croisés calculés automatiquement

================================================================================
VÉRIFICATIONS
================================================================================

Après installation/migration, vérifier:

1. Structure des tables :
   DESCRIBE taux;
   DESCRIBE shops;
   DESCRIBE operations;

2. Taux de change actifs :
   SELECT * FROM taux WHERE est_actif = TRUE;

3. Configuration des shops :
   SELECT id, designation, devise_principale, devise_secondaire FROM shops;

4. Statistiques :
   SELECT * FROM v_sync_status;
   SELECT * FROM v_unsync_entities;

================================================================================
MAINTENANCE
================================================================================

Quotidien:
- Mettre à jour les taux de change selon le marché
- Vérifier les opérations non synchronisées

Hebdomadaire:
- Optimiser les tables (OPTIMIZE TABLE)
- Vérifier l'intégrité des données

Mensuel:
- Désactiver les anciens taux (> 30 jours)
- Nettoyer les logs de synchronisation
- Sauvegarder la base de données

================================================================================
SUPPORT ET DÉPANNAGE
================================================================================

Consulter le fichier guide_installation.sql pour:
- Exemples de requêtes complexes
- Fonctions de conversion de devises
- Commandes de rollback
- Solutions aux problèmes courants

En cas de problème majeur:
1. Restaurer la sauvegarde
2. Consulter les logs MySQL
3. Vérifier les contraintes de clés étrangères
4. Réexécuter la migration avec les corrections

================================================================================
COMPATIBILITÉ
================================================================================

- MySQL 5.7+
- MariaDB 10.2+
- Encodage: UTF8MB4
- Collation: utf8mb4_unicode_ci

================================================================================
VERSION
================================================================================

Version: 2.0.0
Date: 2025-11-08
Support: Multi-devises (USD, CDF, UGX)
Synchronisation: Bidirectionnelle

================================================================================
