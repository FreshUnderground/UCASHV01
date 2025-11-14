-- Script de création des tables de synchronisation UCASH
-- Version 2.0.0 - Support synchronisation bidirectionnelle + Multi-devises (USD/CDF/UGX)

-- Table des shops avec champs de synchronisation et support multi-devises

DROP DATABASE if EXISTS ucash_db;
CREATE DATABASE ucash_db;
USE ucash_db;

CREATE TABLE IF NOT EXISTS shops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    designation VARCHAR(255) NOT NULL,
    localisation VARCHAR(255) NOT NULL,
    capital_initial DECIMAL(15,2) DEFAULT 0.00,
    
    -- Devises supportées (2 max)
    devise_principale VARCHAR(10) DEFAULT 'USD' NOT NULL,
    devise_secondaire VARCHAR(10) DEFAULT NULL,
    
    -- Capitaux en devise principale (USD par défaut)
    capital_actuel DECIMAL(15,2) DEFAULT 0.00,
    capital_cash DECIMAL(15,2) DEFAULT 0.00,
    capital_airtel_money DECIMAL(15,2) DEFAULT 0.00,
    capital_mpesa DECIMAL(15,2) DEFAULT 0.00,
    capital_orange_money DECIMAL(15,2) DEFAULT 0.00,
    
    -- Capitaux en devise secondaire (CDF ou UGX)
    capital_actuel_devise2 DECIMAL(15,2) DEFAULT NULL,
    capital_cash_devise2 DECIMAL(15,2) DEFAULT NULL,
    capital_airtel_money_devise2 DECIMAL(15,2) DEFAULT NULL,
    capital_mpesa_devise2 DECIMAL(15,2) DEFAULT NULL,
    capital_orange_money_devise2 DECIMAL(15,2) DEFAULT NULL,
    
    creances DECIMAL(15,2) DEFAULT 0.00,
    dettes DECIMAL(15,2) DEFAULT 0.00,
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Index pour optimiser les requêtes de synchronisation
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_devise_principale (devise_principale),
    INDEX idx_devise_secondaire (devise_secondaire),
    UNIQUE KEY unique_designation (designation)
);

-- Table des agents avec champs de synchronisation
CREATE TABLE IF NOT EXISTS agents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    nom VARCHAR(255) DEFAULT '',
    shop_id INT NOT NULL,
    role ENUM('ADMIN', 'AGENT') DEFAULT 'AGENT',
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Contraintes et index
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_shop (shop_id),
    UNIQUE KEY unique_username (username)
);

-- Table des clients avec champs de synchronisation
CREATE TABLE IF NOT EXISTS clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    adresse TEXT,
    solde DECIMAL(15,2) DEFAULT 0.00,
    shop_id INT NOT NULL,
    agent_id INT DEFAULT NULL,
    role ENUM('CLIENT') DEFAULT 'CLIENT',
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Contraintes et index
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_shop (shop_id),
    INDEX idx_agent (agent_id),
    UNIQUE KEY unique_telephone (telephone)
);

-- Table des opérations avec champs de synchronisation et support multi-devises
CREATE TABLE IF NOT EXISTS operations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'virement') NOT NULL,
    montant_brut DECIMAL(15,2) NOT NULL,
    montant_net DECIMAL(15,2) NOT NULL,
    commission DECIMAL(15,2) DEFAULT 0.00,
    devise VARCHAR(10) DEFAULT 'USD' NOT NULL,
    client_id INT DEFAULT NULL,
    shop_source_id INT NOT NULL,
    shop_destination_id INT DEFAULT NULL,
    agent_id INT NOT NULL,
    mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney') DEFAULT 'cash',
    statut ENUM('enAttente', 'validee', 'terminee', 'annulee') DEFAULT 'terminee',
    reference VARCHAR(100) DEFAULT NULL,
    notes TEXT,
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Contraintes et index
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    FOREIGN KEY (shop_source_id) REFERENCES shops(id) ON DELETE CASCADE,
    FOREIGN KEY (shop_destination_id) REFERENCES shops(id) ON DELETE SET NULL,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_client (client_id),
    INDEX idx_shop_source (shop_source_id),
    INDEX idx_shop_destination (shop_destination_id),
    INDEX idx_agent (agent_id),
    INDEX idx_reference (reference),
    INDEX idx_statut (statut),
    INDEX idx_type (type),
    INDEX idx_devise (devise)
);

-- Table des taux de change avec champs de synchronisation et support paires de devises
CREATE TABLE IF NOT EXISTS taux (
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

-- Table des commissions avec champs de synchronisation
CREATE TABLE IF NOT EXISTS commissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('SORTANT', 'ENTRANT') NOT NULL,
    taux DECIMAL(5,2) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Champs de synchronisation
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    
    -- Index
    INDEX idx_last_modified (last_modified_at),
    INDEX idx_synced (is_synced, synced_at),
    INDEX idx_type (type),
    UNIQUE KEY unique_type (type)
);

-- Table de métadonnées de synchronisation
CREATE TABLE IF NOT EXISTS sync_metadata (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    last_sync_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_count INT DEFAULT 0,
    last_sync_user VARCHAR(100) DEFAULT 'system',
    notes TEXT,
    
    UNIQUE KEY unique_table (table_name),
    INDEX idx_last_sync (last_sync_date)
);

-- Insertion des métadonnées initiales
-- Handle both cases: with and without notes column
INSERT IGNORE INTO sync_metadata (table_name, sync_count) VALUES
('shops', 0),
('agents', 0),
('clients', 0),
('operations', 0),
('taux', 0),
('commissions', 0);

-- Update the entries to add notes if the column exists
UPDATE sync_metadata SET notes = 'Table des shops UCASH' WHERE table_name = 'shops' AND notes IS NULL;
UPDATE sync_metadata SET notes = 'Table des agents UCASH' WHERE table_name = 'agents' AND notes IS NULL;
UPDATE sync_metadata SET notes = 'Table des clients UCASH' WHERE table_name = 'clients' AND notes IS NULL;
UPDATE sync_metadata SET notes = 'Table des opérations UCASH' WHERE table_name = 'operations' AND notes IS NULL;
UPDATE sync_metadata SET notes = 'Table des taux de change' WHERE table_name = 'taux' AND notes IS NULL;
UPDATE sync_metadata SET notes = 'Table des commissions' WHERE table_name = 'commissions' AND notes IS NULL;

-- Triggers pour mise à jour automatique des métadonnées
-- Note: Simplified trigger syntax for better PHP execution compatibility

-- Drop existing triggers first to avoid conflicts
DROP TRIGGER IF EXISTS shops_sync_update;
DROP TRIGGER IF EXISTS agents_sync_update;
DROP TRIGGER IF EXISTS clients_sync_update;
DROP TRIGGER IF EXISTS operations_sync_update;
DROP TRIGGER IF EXISTS taux_sync_update;
DROP TRIGGER IF EXISTS commissions_sync_update;

-- Trigger pour shops
CREATE TRIGGER shops_sync_update 
AFTER UPDATE ON shops 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'shops';

-- Trigger pour agents
CREATE TRIGGER agents_sync_update 
AFTER UPDATE ON agents 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'agents';

-- Trigger pour clients
CREATE TRIGGER clients_sync_update 
AFTER UPDATE ON clients 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'clients';

-- Trigger pour operations
CREATE TRIGGER operations_sync_update 
AFTER UPDATE ON operations 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'operations';

-- Trigger pour taux
CREATE TRIGGER taux_sync_update 
AFTER UPDATE ON taux 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'taux';

-- Trigger pour commissions
CREATE TRIGGER commissions_sync_update 
AFTER UPDATE ON commissions 
FOR EACH ROW 
UPDATE sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'commissions';

-- Index pour optimiser les requêtes de synchronisation
-- Most compatible approach: Create indexes one by one with error handling

-- Note: We'll use a simple approach that should work in most MySQL versions
-- If indexes already exist, the CREATE INDEX statements will fail, but that's OK

-- Shops indexes
-- Note: We can't use CREATE INDEX IF NOT EXISTS in older MySQL versions
-- So we'll just try to create them and let them fail if they already exist

-- Agents index

-- Clients index

-- Operations index

-- Taux index

-- Commissions index

-- Procédures stockées pour la synchronisation
-- Note: Simplified approach for better PHP execution compatibility

-- Drop existing procedure first
DROP PROCEDURE IF EXISTS MarkEntitiesAsSynced;

-- Simple approach: Use direct SQL statements instead of complex stored procedures
-- This is more compatible with PHP execution and different MySQL versions

CREATE PROCEDURE IF NOT EXISTS MarkEntitiesAsSynced(
    IN p_table_name VARCHAR(100),
    IN p_ids TEXT,
    IN p_user_id VARCHAR(100)
)
BEGIN
    DECLARE sql_stmt TEXT;
    SET sql_stmt = CONCAT('UPDATE ', p_table_name, ' SET is_synced = TRUE, synced_at = NOW(), last_modified_by = ''', p_user_id, ''' WHERE id IN (', p_ids, ')');
    SET @sql = sql_stmt;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END;

-- Vues pour le monitoring
CREATE OR REPLACE VIEW v_sync_status AS
SELECT 
    table_name,
    last_sync_date,
    sync_count,
    last_sync_user,
    CASE 
        WHEN last_sync_date > DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN 'UP_TO_DATE'
        WHEN last_sync_date > DATE_SUB(NOW(), INTERVAL 24 HOUR) THEN 'STALE'
        ELSE 'VERY_STALE'
    END as status
FROM sync_metadata;

CREATE OR REPLACE VIEW v_unsync_entities AS
SELECT 
    'shops' as table_name,
    COUNT(*) as unsync_count
FROM shops 
WHERE is_synced = FALSE
UNION ALL
SELECT 
    'agents' as table_name,
    COUNT(*) as unsync_count
FROM agents 
WHERE is_synced = FALSE
UNION ALL
SELECT 
    'clients' as table_name,
    COUNT(*) as unsync_count
FROM clients 
WHERE is_synced = FALSE
UNION ALL
SELECT 
    'operations' as table_name,
    COUNT(*) as unsync_count
FROM operations 
WHERE is_synced = FALSE
UNION ALL
SELECT 
    'taux' as table_name,
    COUNT(*) as unsync_count
FROM taux 
WHERE is_synced = FALSE
UNION ALL
SELECT 
    'commissions' as table_name,
    COUNT(*) as unsync_count
FROM commissions 
WHERE is_synced = FALSE;

-- Insertion des données initiales (taux de change par défaut)
INSERT IGNORE INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('USD', 'CDF', 2500.0000, 'ACHAT', TRUE),
('USD', 'CDF', 2550.0000, 'VENTE', TRUE),
('USD', 'CDF', 2525.0000, 'MOYEN', TRUE),
('USD', 'UGX', 3650.0000, 'ACHAT', TRUE),
('USD', 'UGX', 3750.0000, 'VENTE', TRUE),
('USD', 'UGX', 3700.0000, 'MOYEN', TRUE);

-- Insertion des commissions par défaut
INSERT IGNORE INTO commissions (type, taux, description, is_active) VALUES
('SORTANT', 0.05, 'Commission pour les transferts sortants', TRUE),
('ENTRANT', 0.03, 'Commission pour les transferts entrants', TRUE);

-- Commentaires sur les tables
ALTER TABLE shops COMMENT = 'Table des shops UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE agents COMMENT = 'Table des agents UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE clients COMMENT = 'Table des clients UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE operations COMMENT = 'Table des opérations UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE taux COMMENT = 'Table des taux de change UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE commissions COMMENT = 'Table des commissions UCASH avec support synchronisation bidirectionnelle';
ALTER TABLE sync_metadata COMMENT = 'Métadonnées de synchronisation pour toutes les tables UCASH';

-- Affichage du statut final
SELECT 'Tables de synchronisation UCASH créées avec succès!' as message;
SELECT * FROM v_sync_status;
SELECT * FROM v_unsync_entities;
