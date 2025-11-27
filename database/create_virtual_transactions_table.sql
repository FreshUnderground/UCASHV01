-- ========================================================================
-- TABLE DE GESTION DES TRANSACTIONS VIRTUELLES (MOBILE MONEY)
-- ========================================================================

-- Table principale des transactions virtuelles
CREATE TABLE IF NOT EXISTS virtual_transactions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    reference VARCHAR(100) NOT NULL UNIQUE,
    montant_virtuel DECIMAL(15,2) NOT NULL,
    frais DECIMAL(15,2) DEFAULT 0.00,
    montant_cash DECIMAL(15,2) NOT NULL,
    devise VARCHAR(10) DEFAULT 'USD',
    
    -- Informations SIM
    sim_numero VARCHAR(20) NOT NULL,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(255),
    
    -- Informations agent
    agent_id INT NOT NULL,
    agent_username VARCHAR(100),
    
    -- Informations client (complétées lors de la validation)
    client_nom VARCHAR(255),
    client_telephone VARCHAR(20),
    
    -- Statut de la transaction
    statut ENUM('enAttente', 'validee', 'annulee') DEFAULT 'enAttente',
    
    -- Dates et tracking
    date_enregistrement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_validation DATETIME,
    notes TEXT,
    
    -- Synchronization
    last_modified_at DATETIME,
    last_modified_by VARCHAR(100),
    is_synced TINYINT(1) DEFAULT 0,
    synced_at DATETIME,
    
    INDEX idx_vt_reference (reference),
    INDEX idx_vt_sim (sim_numero),
    INDEX idx_vt_shop (shop_id),
    INDEX idx_vt_agent (agent_id),
    INDEX idx_vt_statut (statut),
    INDEX idx_vt_date_enregistrement (date_enregistrement),
    INDEX idx_vt_date_validation (date_validation),
    INDEX idx_vt_sync (is_synced, last_modified_at),
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT,
    FOREIGN KEY (sim_numero) REFERENCES sims(numero) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================================================
-- DONNÉES DE TEST (OPTIONNEL)
-- ========================================================================

-- Insertion de transactions virtuelles de test (si la table est vide)
-- INSERT IGNORE INTO virtual_transactions 
--     (reference, montant_virtuel, frais, montant_cash, devise, sim_numero, shop_id, shop_designation, agent_id, agent_username, statut, date_enregistrement)
-- VALUES 
--     ('REF001', 100.00, 2.00, 98.00, 'USD', '0972345678', 1, 'SHOP DURBA', 1, 'agent1', 'enAttente', NOW()),
--     ('REF002', 50.00, 1.00, 49.00, 'USD', '0972345678', 1, 'SHOP DURBA', 1, 'agent1', 'validee', NOW());

-- ========================================================================
-- VUES UTILES
-- ========================================================================

-- Vue des transactions en attente par shop
CREATE OR REPLACE VIEW v_virtual_transactions_en_attente AS
SELECT 
    vt.*,
    s.operateur as sim_operateur,
    sh.designation as shop_nom,
    sh.localisation as shop_localisation
FROM virtual_transactions vt
LEFT JOIN sims s ON vt.sim_numero COLLATE utf8mb4_unicode_ci = s.numero COLLATE utf8mb4_unicode_ci
LEFT JOIN shops sh ON vt.shop_id = sh.id
WHERE vt.statut = 'enAttente'
ORDER BY vt.date_enregistrement DESC;

-- Vue des transactions validées par shop
CREATE OR REPLACE VIEW v_virtual_transactions_validees AS
SELECT 
    vt.*,
    s.operateur as sim_operateur,
    sh.designation as shop_nom,
    sh.localisation as shop_localisation
FROM virtual_transactions vt
LEFT JOIN sims s ON vt.sim_numero COLLATE utf8mb4_unicode_ci = s.numero COLLATE utf8mb4_unicode_ci
LEFT JOIN shops sh ON vt.shop_id = sh.id
WHERE vt.statut = 'validee'
ORDER BY vt.date_validation DESC;

-- ========================================================================
-- STATISTIQUES QUOTIDIENNES PAR SHOP
-- ========================================================================

-- Vue des statistiques quotidiennes par shop
CREATE OR REPLACE VIEW v_virtual_transactions_daily_stats AS
SELECT 
    shop_id,
    shop_designation,
    DATE(date_enregistrement) as date_transaction,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN statut = 'enAttente' THEN 1 ELSE 0 END) as transactions_en_attente,
    SUM(CASE WHEN statut = 'validee' THEN 1 ELSE 0 END) as transactions_validees,
    SUM(CASE WHEN statut = 'validee' THEN montant_virtuel ELSE 0 END) as total_virtuel_encaisse,
    SUM(CASE WHEN statut = 'validee' THEN frais ELSE 0 END) as total_frais,
    SUM(CASE WHEN statut = 'validee' THEN montant_cash ELSE 0 END) as total_cash_servi
FROM virtual_transactions
GROUP BY shop_id, shop_designation, DATE(date_enregistrement)
ORDER BY date_transaction DESC, shop_id;
