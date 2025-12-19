-- Table pour gérer les règlements triangulaires de dettes inter-shops
-- Scénario : Shop A doit à Shop C, mais Shop B reçoit le paiement pour le compte de Shop C
--
-- Impacts:
-- - Dette de Shop A envers Shop C: diminue
-- - Dette de Shop B envers Shop C: augmente
--
-- Exemple concret:
-- - Shop MOKU doit 5000 USD à Shop NGANGAZU
-- - Agent de MOKU paie 5000 USD à Shop BUKAVU pour le compte de NGANGAZU
-- - Résultat:
--   * MOKU doit maintenant 0 USD à NGANGAZU (dette diminuée de 5000)
--   * BUKAVU doit maintenant 5000 USD à NGANGAZU (dette augmentée de 5000)

CREATE TABLE IF NOT EXISTS triangular_debt_settlements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(50) NOT NULL UNIQUE,
    
    -- Shops impliqués dans le règlement triangulaire
    shop_debtor_id INT NOT NULL COMMENT 'Shop A (qui doit l\'argent initialement)',
    shop_debtor_designation VARCHAR(255) DEFAULT NULL,
    shop_intermediary_id INT NOT NULL COMMENT 'Shop B (qui reçoit le paiement)',
    shop_intermediary_designation VARCHAR(255) DEFAULT NULL,
    shop_creditor_id INT NOT NULL COMMENT 'Shop C (à qui l\'argent est dû)',
    shop_creditor_designation VARCHAR(255) DEFAULT NULL,
    
    -- Informations du règlement
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) DEFAULT 'USD',
    date_reglement DATETIME NOT NULL,
    mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney', 'virement') DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    
    -- Agent qui a effectué l'opération
    agent_id INT NOT NULL,
    agent_username VARCHAR(100) DEFAULT NULL,
    
    -- Métadonnées de synchronisation
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100) DEFAULT NULL,
    is_synced TINYINT(1) DEFAULT 0,
    synced_at DATETIME DEFAULT NULL,
    
    -- Index pour performance
    KEY idx_shop_debtor (shop_debtor_id),
    KEY idx_shop_intermediary (shop_intermediary_id),
    KEY idx_shop_creditor (shop_creditor_id),
    KEY idx_date_reglement (date_reglement),
    KEY idx_agent (agent_id),
    KEY idx_reference (reference),
    KEY idx_synced (is_synced),
    
    -- Contraintes d'intégrité
    CONSTRAINT chk_different_shops CHECK (
        shop_debtor_id != shop_intermediary_id AND
        shop_debtor_id != shop_creditor_id AND
        shop_intermediary_id != shop_creditor_id
    ),
    CONSTRAINT chk_montant_positive CHECK (montant > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Règlements triangulaires de dettes entre 3 shops';

-- Index composite pour recherches fréquentes
CREATE INDEX idx_debtor_creditor ON triangular_debt_settlements(shop_debtor_id, shop_creditor_id);
CREATE INDEX idx_intermediary_creditor ON triangular_debt_settlements(shop_intermediary_id, shop_creditor_id);
CREATE INDEX idx_date_sync ON triangular_debt_settlements(date_reglement, is_synced);
