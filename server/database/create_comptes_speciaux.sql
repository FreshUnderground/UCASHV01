-- Table pour les comptes spéciaux (FRAIS et DÉPENSE)
CREATE TABLE IF NOT EXISTS comptes_speciaux (
    id BIGINT PRIMARY KEY,
    type ENUM('FRAIS', 'DEPENSE') NOT NULL,
    type_transaction ENUM('DEPOT', 'RETRAIT', 'SORTIE', 'COMMISSION_AUTO') NOT NULL,
    montant DECIMAL(15, 2) NOT NULL COMMENT 'Positif pour dépôts/commissions, négatif pour retraits/sorties',
    description VARCHAR(500) NOT NULL,
    shop_id INT,
    date_transaction DATETIME NOT NULL,
    operation_id BIGINT COMMENT 'Lien vers l\'opération pour COMMISSION_AUTO',
    agent_id INT,
    agent_username VARCHAR(100),
    
    -- Métadonnées de synchronisation
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    is_synced TINYINT(1) DEFAULT 0,
    synced_at DATETIME,
    
    INDEX idx_type (type),
    INDEX idx_type_transaction (type_transaction),
    INDEX idx_shop_id (shop_id),
    INDEX idx_date_transaction (date_transaction),
    INDEX idx_operation_id (operation_id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_synced (is_synced)
);

-- Vues pour faciliter les rapports

-- Vue: Total FRAIS par shop
CREATE OR REPLACE VIEW v_frais_par_shop AS
SELECT 
    shop_id,
    COUNT(*) as nombre_frais,
    SUM(montant) as total_frais,
    DATE(date_transaction) as date_jour
FROM comptes_speciaux
WHERE type = 'FRAIS'
GROUP BY shop_id, DATE(date_transaction);

-- Vue: Total DÉPENSES par shop
CREATE OR REPLACE VIEW v_depenses_par_shop AS
SELECT 
    shop_id,
    COUNT(*) as nombre_depenses,
    SUM(montant) as total_depenses,
    DATE(date_transaction) as date_jour
FROM comptes_speciaux
WHERE type = 'DEPENSE'
GROUP BY shop_id, DATE(date_transaction);

-- Vue: Bénéfice net par shop
CREATE OR REPLACE VIEW v_benefice_net_par_shop AS
SELECT 
    COALESCE(f.shop_id, d.shop_id) as shop_id,
    COALESCE(f.date_jour, d.date_jour) as date_jour,
    COALESCE(f.total_frais, 0) as total_frais,
    COALESCE(d.total_depenses, 0) as total_depenses,
    COALESCE(f.total_frais, 0) - COALESCE(d.total_depenses, 0) as benefice_net
FROM v_frais_par_shop f
LEFT JOIN v_depenses_par_shop d ON f.shop_id = d.shop_id AND f.date_jour = d.date_jour
UNION
SELECT 
    d.shop_id,
    d.date_jour,
    COALESCE(f.total_frais, 0) as total_frais,
    d.total_depenses,
    COALESCE(f.total_frais, 0) - d.total_depenses as benefice_net
FROM v_depenses_par_shop d
LEFT JOIN v_frais_par_shop f ON d.shop_id = f.shop_id AND d.date_jour = f.date_jour
WHERE f.shop_id IS NULL;
