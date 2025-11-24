-- ========================================================================
-- TABLES DE GESTION DES CARTES SIM
-- ========================================================================

-- Table principale des SIMs
CREATE TABLE IF NOT EXISTS sims (
    id INT PRIMARY KEY AUTO_INCREMENT,
    numero VARCHAR(20) NOT NULL UNIQUE,
    operateur VARCHAR(50) NOT NULL,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(255),
    solde_initial DECIMAL(15,2) DEFAULT 0.00,
    solde_actuel DECIMAL(15,2) DEFAULT 0.00,
    statut ENUM('active', 'suspendue', 'perdue', 'desactivee') DEFAULT 'active',
    motif_suspension TEXT,
    date_creation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_suspension DATETIME,
    cree_par VARCHAR(100),
    last_modified_at DATETIME,
    last_modified_by VARCHAR(100),
    is_synced TINYINT(1) DEFAULT 0,
    synced_at DATETIME,
    INDEX idx_sim_numero (numero),
    INDEX idx_sim_shop (shop_id),
    INDEX idx_sim_operateur (operateur),
    INDEX idx_sim_statut (statut),
    INDEX idx_sim_sync (is_synced, last_modified_at),
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table de l'historique des mouvements/affectations de SIMs
CREATE TABLE IF NOT EXISTS sim_movements (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sim_id INT NOT NULL,
    sim_numero VARCHAR(20) NOT NULL,
    ancien_shop_id INT,
    ancien_shop_designation VARCHAR(255),
    nouveau_shop_id INT NOT NULL,
    nouveau_shop_designation VARCHAR(255) NOT NULL,
    admin_responsable VARCHAR(100) NOT NULL,
    motif TEXT,
    date_movement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME,
    last_modified_by VARCHAR(100),
    is_synced TINYINT(1) DEFAULT 0,
    synced_at DATETIME,
    INDEX idx_movement_sim (sim_id),
    INDEX idx_movement_date (date_movement),
    INDEX idx_movement_shops (ancien_shop_id, nouveau_shop_id),
    INDEX idx_movement_sync (is_synced, last_modified_at),
    FOREIGN KEY (sim_id) REFERENCES sims(id) ON DELETE CASCADE,
    FOREIGN KEY (nouveau_shop_id) REFERENCES shops(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================================================
-- DONNÉES DE TEST
-- ========================================================================

-- Insertion de SIMs de test (si la table est vide)
INSERT IGNORE INTO sims (numero, operateur, shop_id, shop_designation, solde_initial, solde_actuel, statut, cree_par, date_creation)
VALUES 
    ('0850123456', 'Airtel', 1, 'Shop Central', 1000.00, 950.00, 'active', 'admin', NOW()),
    ('0810234567', 'Vodacom', 1, 'Shop Central', 500.00, 480.00, 'active', 'admin', NOW()),
    ('0990345678', 'Orange', 2, 'Shop Nord', 750.00, 730.00, 'active', 'admin', NOW()),
    ('0890456789', 'Africell', 2, 'Shop Nord', 300.00, 300.00, 'active', 'admin', NOW()),
    ('0850567890', 'Airtel', 3, 'Shop Sud', 1200.00, 1180.00, 'active', 'admin', NOW());

-- Insertion de mouvements de test
INSERT IGNORE INTO sim_movements (sim_id, sim_numero, ancien_shop_id, ancien_shop_designation, nouveau_shop_id, nouveau_shop_designation, admin_responsable, motif, date_movement)
SELECT 
    id,
    numero,
    NULL,
    NULL,
    shop_id,
    shop_designation,
    'admin',
    'Affectation initiale',
    date_creation
FROM sims
WHERE id NOT IN (SELECT sim_id FROM sim_movements);
