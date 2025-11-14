-- Script de migration UCASH vers support Multi-devises
-- Version 2.0.0 - Migration de la structure existante vers multi-devises
-- Date: 2025-11-08

-- ============================================================================
-- PARTIE 1: MIGRATION DE LA TABLE TAUX (devise → devise_source/devise_cible)
-- ============================================================================

-- Étape 1: Créer une table temporaire pour sauvegarder les anciennes données
CREATE TABLE IF NOT EXISTS taux_backup AS SELECT * FROM taux;

-- Étape 2: Supprimer l'ancienne table taux
DROP TABLE IF EXISTS taux;

-- Étape 3: Recréer la table taux avec la nouvelle structure
CREATE TABLE taux (
    id INT AUTO_INCREMENT PRIMARY KEY,
    devise_source VARCHAR(10) DEFAULT 'USD' NOT NULL,
    devise_cible VARCHAR(10) NOT NULL,
    taux DECIMAL(10,4) NOT NULL,
    type ENUM('ACHAT', 'VENTE', 'MOYEN', 'NATIONAL', 'INTERNATIONAL_ENTRANT', 'INTERNATIONAL_SORTANT') NOT NULL,
    date_effet TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    est_actif BOOLEAN DEFAULT TRUE,
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Index
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_devise_source (devise_source),
    INDEX idx_devise_cible (devise_cible),
    INDEX idx_type (type),
    INDEX idx_date_effet (date_effet),
    INDEX idx_est_actif (est_actif),
    UNIQUE KEY unique_devise_pair_type (devise_source, devise_cible, type)
);

-- Étape 4: Migrer les anciennes données
INSERT INTO taux (
    id, 
    devise_source, 
    devise_cible, 
    taux, 
    type, 
    est_actif, 
    last_modified_at, 
    last_modified_by, 
    created_at
)
SELECT 
    id,
    'USD' as devise_source,
    CASE 
        WHEN devise = 'USD' THEN 'CDF'
        ELSE devise
    END as devise_cible,
    taux,
    CASE 
        WHEN type = 'NATIONAL' THEN 'MOYEN'
        ELSE type
    END as type,
    is_active as est_actif,
    last_modified_at,
    last_modified_by,
    created_at
FROM taux_backup;

-- Supprimer la table de backup (optionnel - commenter si vous voulez garder)
-- DROP TABLE IF EXISTS taux_backup;

-- ============================================================================
-- PARTIE 2: MIGRATION DE LA TABLE SHOPS (ajout colonnes multi-devises)
-- ============================================================================

-- Ajouter les colonnes de devises si elles n'existent pas
ALTER TABLE shops 
ADD COLUMN IF NOT EXISTS devise_principale VARCHAR(10) DEFAULT 'USD' NOT NULL AFTER localisation,
ADD COLUMN IF NOT EXISTS devise_secondaire VARCHAR(10) DEFAULT NULL AFTER devise_principale;

-- Ajouter les colonnes de capital en devise secondaire
ALTER TABLE shops
ADD COLUMN IF NOT EXISTS capital_actuel_devise2 DECIMAL(15,2) DEFAULT NULL AFTER capital_orange_money,
ADD COLUMN IF NOT EXISTS capital_cash_devise2 DECIMAL(15,2) DEFAULT NULL AFTER capital_actuel_devise2,
ADD COLUMN IF NOT EXISTS capital_airtel_money_devise2 DECIMAL(15,2) DEFAULT NULL AFTER capital_cash_devise2,
ADD COLUMN IF NOT EXISTS capital_mpesa_devise2 DECIMAL(15,2) DEFAULT NULL AFTER capital_airtel_money_devise2,
ADD COLUMN IF NOT EXISTS capital_orange_money_devise2 DECIMAL(15,2) DEFAULT NULL AFTER capital_mpesa_devise2;

-- Ajouter les index pour les devises
CREATE INDEX IF NOT EXISTS idx_devise_principale ON shops (devise_principale);
CREATE INDEX IF NOT EXISTS idx_devise_secondaire ON shops (devise_secondaire);

-- ============================================================================
-- PARTIE 3: MIGRATION DE LA TABLE OPERATIONS (ajout colonne devise)
-- ============================================================================

-- Ajouter la colonne devise si elle n'existe pas
ALTER TABLE operations 
ADD COLUMN IF NOT EXISTS devise VARCHAR(10) DEFAULT 'USD' NOT NULL AFTER commission;

-- Ajouter l'index pour la devise
CREATE INDEX IF NOT EXISTS idx_devise ON operations (devise);

-- ============================================================================
-- PARTIE 4: INSERTION DES TAUX DE CHANGE PAR DÉFAUT
-- ============================================================================

-- Supprimer les anciens taux pour éviter les doublons
DELETE FROM taux WHERE devise_source = 'USD' AND devise_cible IN ('CDF', 'UGX');

-- Insérer les taux de change par défaut USD → CDF
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('USD', 'CDF', 2500.00, 'ACHAT', TRUE),
('USD', 'CDF', 2550.00, 'VENTE', TRUE),
('USD', 'CDF', 2525.00, 'MOYEN', TRUE);

-- Insérer les taux de change par défaut USD → UGX
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('USD', 'UGX', 3650.00, 'ACHAT', TRUE),
('USD', 'UGX', 3750.00, 'VENTE', TRUE),
('USD', 'UGX', 3700.00, 'MOYEN', TRUE);

-- Insérer les taux de change croisés CDF → UGX (calculés automatiquement)
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('CDF', 'UGX', 1.4760, 'ACHAT', TRUE),
('CDF', 'UGX', 1.4706, 'VENTE', TRUE),
('CDF', 'UGX', 1.4653, 'MOYEN', TRUE);

-- ============================================================================
-- PARTIE 5: VÉRIFICATIONS ET STATISTIQUES
-- ============================================================================

-- Afficher le résumé de la migration
SELECT 'Migration terminée avec succès!' as message;

-- Statistiques sur les taux
SELECT 
    'Taux de change' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT devise_source) as devises_source,
    COUNT(DISTINCT devise_cible) as devises_cible,
    COUNT(DISTINCT type) as types
FROM taux;

-- Statistiques sur les shops
SELECT 
    'Shops' as table_name,
    COUNT(*) as total_shops,
    COUNT(DISTINCT devise_principale) as devises_principales_utilisees,
    SUM(CASE WHEN devise_secondaire IS NOT NULL THEN 1 ELSE 0 END) as shops_avec_devise_secondaire
FROM shops;

-- Statistiques sur les opérations
SELECT 
    'Operations' as table_name,
    COUNT(*) as total_operations,
    COUNT(DISTINCT devise) as devises_utilisees,
    SUM(CASE WHEN devise = 'USD' THEN 1 ELSE 0 END) as operations_usd,
    SUM(CASE WHEN devise = 'CDF' THEN 1 ELSE 0 END) as operations_cdf,
    SUM(CASE WHEN devise = 'UGX' THEN 1 ELSE 0 END) as operations_ugx
FROM operations;

-- Afficher tous les taux de change actifs
SELECT 
    CONCAT(devise_source, ' → ', devise_cible) as paire_devise,
    taux,
    type,
    est_actif,
    date_effet
FROM taux 
WHERE est_actif = TRUE
ORDER BY devise_source, devise_cible, type;

-- ============================================================================
-- PARTIE 6: COMMANDES DE ROLLBACK (EN CAS DE PROBLÈME)
-- ============================================================================

-- Pour annuler la migration (décommenter si nécessaire):
/*
-- Restaurer la table taux depuis la backup
DROP TABLE IF EXISTS taux;
CREATE TABLE taux AS SELECT * FROM taux_backup;

-- Supprimer les colonnes ajoutées aux shops
ALTER TABLE shops 
DROP COLUMN IF EXISTS devise_principale,
DROP COLUMN IF EXISTS devise_secondaire,
DROP COLUMN IF EXISTS capital_actuel_devise2,
DROP COLUMN IF EXISTS capital_cash_devise2,
DROP COLUMN IF EXISTS capital_airtel_money_devise2,
DROP COLUMN IF EXISTS capital_mpesa_devise2,
DROP COLUMN IF EXISTS capital_orange_money_devise2;

-- Supprimer la colonne devise des opérations
ALTER TABLE operations DROP COLUMN IF EXISTS devise;
*/
