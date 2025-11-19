-- ========================================
-- UCASH DATABASE SCHEMA - MySQL
-- Système de gestion de transfert d'argent
-- ========================================

-- Créer la base de données
CREATE DATABASE IF NOT EXISTS ucash_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE ucash_db;

-- ========================================
-- TABLE: users (Utilisateurs/Administrateurs)
-- ========================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('ADMIN', 'AGENT', 'CLIENT') NOT NULL DEFAULT 'AGENT',
    shop_id INT NULL,
    nom VARCHAR(100) NULL,
    adresse VARCHAR(255) NULL,
    telephone VARCHAR(20) NULL,
    solde DECIMAL(15, 2) NULL DEFAULT 0.00,
    devise VARCHAR(10) NULL DEFAULT 'USD',
    created_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_role (role),
    INDEX idx_shop_id (shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: shops (Points de vente/Agences)
-- ========================================
CREATE TABLE IF NOT EXISTS shops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    designation VARCHAR(100) NOT NULL,
    localisation VARCHAR(255) NOT NULL,
    
    -- Devises supportées
    devise_principale VARCHAR(10) NOT NULL DEFAULT 'USD',
    devise_secondaire VARCHAR(10) NULL COMMENT 'CDF, UGX, ou NULL',
    
    -- Capitaux en devise principale (USD)
    capital_initial DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    capital_actuel DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    capital_cash DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    capital_airtel_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    capital_mpesa DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    capital_orange_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Capitaux en devise secondaire
    capital_initial_devise2 DECIMAL(15, 2) NULL,
    capital_actuel_devise2 DECIMAL(15, 2) NULL,
    capital_cash_devise2 DECIMAL(15, 2) NULL,
    capital_airtel_money_devise2 DECIMAL(15, 2) NULL,
    capital_mpesa_devise2 DECIMAL(15, 2) NULL,
    capital_orange_money_devise2 DECIMAL(15, 2) NULL,
    
    creances DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    dettes DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Métadonnées de synchronisation
    uuid VARCHAR(36) NULL UNIQUE,
    last_modified_at DATETIME NULL,
    last_modified_by VARCHAR(50) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at DATETIME NULL,
    
    INDEX idx_designation (designation),
    INDEX idx_localisation (localisation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: agents (Agents de shop)
-- ========================================
CREATE TABLE IF NOT EXISTS agents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    shop_id INT NOT NULL,
    nom VARCHAR(100) NULL,
    telephone VARCHAR(20) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME NULL,
    last_modified_by VARCHAR(50) NULL,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_username (username),
    INDEX idx_shop_id (shop_id),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: clients (Clients avec comptes)
-- ========================================
CREATE TABLE IF NOT EXISTS clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    telephone VARCHAR(20) NOT NULL,
    adresse VARCHAR(255) NULL,
    username VARCHAR(50) NULL UNIQUE,
    password VARCHAR(255) NULL,
    numero_compte VARCHAR(50) NULL UNIQUE COMMENT 'Numéro de compte client',
    shop_id INT NOT NULL,
    
    -- Soldes
    solde DECIMAL(15, 2) NOT NULL DEFAULT 0.00 COMMENT 'Solde en devise principale (USD)',
    solde_devise2 DECIMAL(15, 2) NULL COMMENT 'Solde en devise secondaire',
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME NULL,
    last_modified_by VARCHAR(50) NULL,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_nom (nom),
    INDEX idx_telephone (telephone),
    INDEX idx_numero_compte (numero_compte),
    INDEX idx_shop_id (shop_id),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: operations (Toutes les opérations)
-- ========================================
CREATE TABLE IF NOT EXISTS operations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Type d'opération
    type ENUM(
        'transfertNational',
        'transfertInternationalSortant',
        'transfertInternationalEntrant',
        'depot',
        'retrait',
        'virement'
    ) NOT NULL,
    
    -- Montants
    montant_brut DECIMAL(15, 2) NOT NULL,
    commission DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    montant_net DECIMAL(15, 2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    
    -- Informations client
    client_id INT NULL,
    client_nom VARCHAR(100) NULL,
    
    -- Informations shops
    shop_source_id INT NULL,
    shop_source_designation VARCHAR(100) NULL,
    shop_destination_id INT NULL,
    shop_destination_designation VARCHAR(100) NULL,
    
    -- Informations agent
    agent_id INT NOT NULL,
    agent_username VARCHAR(50) NULL,
    
    -- Détails de l'opération
    destinataire VARCHAR(100) NULL,
    telephone_destinataire VARCHAR(20) NULL,
    reference VARCHAR(100) NULL,
    mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney') NOT NULL,
    statut ENUM('enAttente', 'validee', 'terminee', 'annulee') NOT NULL DEFAULT 'terminee',
    notes TEXT NULL,
    observation TEXT NULL COMMENT 'Observations de l\'agent',
    
    -- Dates et tracking
    date_op DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME NULL,
    last_modified_by VARCHAR(50) NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at DATETIME NULL,
    
    -- Code d'opération unique
    code_ops VARCHAR(50) NULL UNIQUE COMMENT 'Code d\'opération unique pour les reçus',
    
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (shop_source_id) REFERENCES shops(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (shop_destination_id) REFERENCES shops(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_type (type),
    INDEX idx_date_op (date_op),
    INDEX idx_client_id (client_id),
    INDEX idx_shop_source_id (shop_source_id),
    INDEX idx_shop_destination_id (shop_destination_id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_statut (statut),
    INDEX idx_reference (reference),
    INDEX idx_code_ops (code_ops)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: flots (Approvisionnement entre shops)
-- ========================================
CREATE TABLE IF NOT EXISTS flots (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Shops impliqués
    shop_source_id INT NOT NULL,
    shop_source_designation VARCHAR(100) NOT NULL,
    shop_destination_id INT NOT NULL,
    shop_destination_designation VARCHAR(100) NOT NULL,
    
    -- Montant et devise
    montant DECIMAL(15, 2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney') NOT NULL,
    
    -- Statut du flot
    statut ENUM('enRoute', 'servi', 'annule') NOT NULL DEFAULT 'enRoute',
    
    -- Agents impliqués
    agent_envoyeur_id INT NOT NULL COMMENT 'Agent qui confie le flot',
    agent_envoyeur_username VARCHAR(50) NULL,
    agent_recepteur_id INT NULL COMMENT 'Agent qui reçoit le flot',
    agent_recepteur_username VARCHAR(50) NULL,
    
    -- Dates
    date_envoi DATETIME NOT NULL,
    date_reception DATETIME NULL,
    
    -- Détails
    notes TEXT NULL,
    reference VARCHAR(100) NULL,
    
    -- Métadonnées de synchronisation
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_at DATETIME NULL,
    last_modified_by VARCHAR(50) NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at DATETIME NULL,
    
    FOREIGN KEY (shop_source_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (shop_destination_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (agent_envoyeur_id) REFERENCES agents(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (agent_recepteur_id) REFERENCES agents(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_shop_source_id (shop_source_id),
    INDEX idx_shop_destination_id (shop_destination_id),
    INDEX idx_statut (statut),
    INDEX idx_date_envoi (date_envoi),
    INDEX idx_agent_envoyeur_id (agent_envoyeur_id),
    INDEX idx_reference (reference)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: commissions (Grille tarifaire)
-- ========================================
CREATE TABLE IF NOT EXISTS commissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_operation ENUM(
        'transfertNational',
        'transfertInternationalSortant',
        'transfertInternationalEntrant',
        'depot',
        'retrait',
        'virement'
    ) NOT NULL,
    montant_min DECIMAL(15, 2) NOT NULL,
    montant_max DECIMAL(15, 2) NOT NULL,
    commission DECIMAL(15, 2) NOT NULL,
    pourcentage DECIMAL(5, 2) NULL COMMENT 'Commission en pourcentage (optionnel)',
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_type_operation (type_operation),
    INDEX idx_devise (devise),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: taux_change (Taux de change)
-- ========================================
CREATE TABLE IF NOT EXISTS taux_change (
    id INT AUTO_INCREMENT PRIMARY KEY,
    devise_source VARCHAR(10) NOT NULL,
    devise_cible VARCHAR(10) NOT NULL,
    taux_achat DECIMAL(15, 6) NOT NULL,
    taux_vente DECIMAL(15, 6) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    date_debut DATE NOT NULL,
    date_fin DATE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_devise_source (devise_source),
    INDEX idx_devise_cible (devise_cible),
    INDEX idx_is_active (is_active),
    INDEX idx_date_debut (date_debut),
    UNIQUE KEY unique_taux (devise_source, devise_cible, date_debut)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: devises (Devises supportées)
-- ========================================
CREATE TABLE IF NOT EXISTS devises (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE COMMENT 'USD, CDF, UGX, etc.',
    nom VARCHAR(50) NOT NULL,
    symbole VARCHAR(10) NOT NULL,
    pays VARCHAR(50) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_code (code),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: journal_caisse (Mouvements de caisse)
-- ========================================
CREATE TABLE IF NOT EXISTS journal_caisse (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    agent_id INT NOT NULL,
    type_mouvement ENUM('entree', 'sortie') NOT NULL,
    montant DECIMAL(15, 2) NOT NULL,
    mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney') NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    libelle VARCHAR(255) NOT NULL,
    reference VARCHAR(100) NULL,
    operation_id INT NULL COMMENT 'Référence à l\'opération liée',
    date_action DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (operation_id) REFERENCES operations(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_shop_id (shop_id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_date_action (date_action),
    INDEX idx_type_mouvement (type_mouvement),
    INDEX idx_operation_id (operation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: rapports_cloture (Rapports de clôture journalière)
-- ========================================
CREATE TABLE IF NOT EXISTS rapports_cloture (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(100) NOT NULL,
    date_rapport DATE NOT NULL,
    
    -- Soldes antérieurs
    solde_anterieur_total DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    solde_anterieur_cash DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    solde_anterieur_airtel_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    solde_anterieur_mpesa DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    solde_anterieur_orange_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Cash disponible
    cash_disponible_total DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cash_disponible_cash DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cash_disponible_airtel_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cash_disponible_mpesa DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cash_disponible_orange_money DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- FLOTs
    flot_recu DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    flot_en_cours DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    flot_servi DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Transferts
    transferts_recus DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    transferts_servis DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Opérations clients
    depots_clients DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    retraits_clients DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Créances et dettes
    total_clients_nous_doivent DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    total_clients_nous_devons DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    total_shops_nous_doivent DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    total_shops_nous_devons DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Capital net
    capital_net DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    
    -- Métadonnées
    genere_par VARCHAR(50) NULL,
    date_generation DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_shop_id (shop_id),
    INDEX idx_date_rapport (date_rapport),
    UNIQUE KEY unique_rapport (shop_id, date_rapport)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- TABLE: transactions (Log de toutes les transactions)
-- ========================================
CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_transaction ENUM('operation', 'flot', 'caisse') NOT NULL,
    reference_id INT NOT NULL COMMENT 'ID dans la table correspondante',
    shop_id INT NOT NULL,
    agent_id INT NOT NULL,
    montant DECIMAL(15, 2) NOT NULL,
    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
    description TEXT NULL,
    date_transaction DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_type_transaction (type_transaction),
    INDEX idx_shop_id (shop_id),
    INDEX idx_agent_id (agent_id),
    INDEX idx_date_transaction (date_transaction)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================
-- DONNÉES INITIALES
-- ========================================

-- Insertion des devises de base
INSERT INTO devises (code, nom, symbole, pays) VALUES
('USD', 'Dollar Américain', '$', 'États-Unis'),
('CDF', 'Franc Congolais', 'FC', 'RD Congo'),
('UGX', 'Shilling Ougandais', 'USh', 'Ouganda')
ON DUPLICATE KEY UPDATE nom=VALUES(nom);

-- Insertion d'un administrateur par défaut
INSERT INTO users (username, password, role, nom) VALUES
('admin', 'admin123', 'ADMIN', 'Administrateur Principal')
ON DUPLICATE KEY UPDATE username=username;

-- Insertion de taux de change de base
INSERT INTO taux_change (devise_source, devise_cible, taux_achat, taux_vente, date_debut) VALUES
('USD', 'CDF', 2800.00, 2850.00, CURDATE()),
('USD', 'UGX', 3700.00, 3750.00, CURDATE()),
('CDF', 'USD', 0.00035, 0.00036, CURDATE()),
('UGX', 'USD', 0.00027, 0.00028, CURDATE())
ON DUPLICATE KEY UPDATE taux_achat=VALUES(taux_achat), taux_vente=VALUES(taux_vente);

-- ========================================
-- VUES UTILES
-- ========================================

-- Vue pour les soldes clients par shop
CREATE OR REPLACE VIEW v_soldes_clients AS
SELECT 
    c.shop_id,
    s.designation AS shop_designation,
    COUNT(c.id) AS nombre_clients,
    SUM(CASE WHEN c.solde > 0 THEN c.solde ELSE 0 END) AS total_creances,
    SUM(CASE WHEN c.solde < 0 THEN ABS(c.solde) ELSE 0 END) AS total_dettes,
    SUM(c.solde) AS solde_net
FROM clients c
INNER JOIN shops s ON c.shop_id = s.id
WHERE c.is_active = TRUE
GROUP BY c.shop_id, s.designation;

-- Vue pour les opérations du jour par shop
CREATE OR REPLACE VIEW v_operations_jour AS
SELECT 
    o.shop_source_id AS shop_id,
    s.designation AS shop_designation,
    DATE(o.date_op) AS date_operation,
    o.type,
    COUNT(o.id) AS nombre_operations,
    SUM(o.montant_net) AS total_montant,
    SUM(o.commission) AS total_commission
FROM operations o
LEFT JOIN shops s ON o.shop_source_id = s.id
WHERE DATE(o.date_op) = CURDATE()
GROUP BY o.shop_source_id, s.designation, DATE(o.date_op), o.type;

-- Vue pour le capital total par shop
CREATE OR REPLACE VIEW v_capital_shops AS
SELECT 
    s.id,
    s.designation,
    s.localisation,
    s.capital_actuel,
    (s.capital_cash + s.capital_airtel_money + s.capital_mpesa + s.capital_orange_money) AS capital_total_calcule,
    s.creances,
    s.dettes,
    (s.capital_actuel + s.creances - s.dettes) AS capital_net
FROM shops s;

-- ========================================
-- PROCEDURES STOCKÉES
-- ========================================

DELIMITER //

-- Procédure pour calculer le rapport de clôture
CREATE PROCEDURE sp_generer_rapport_cloture(
    IN p_shop_id INT,
    IN p_date_rapport DATE,
    IN p_genere_par VARCHAR(50)
)
BEGIN
    DECLARE v_solde_ant_total DECIMAL(15,2);
    DECLARE v_cash_dispo_total DECIMAL(15,2);
    DECLARE v_flot_recu DECIMAL(15,2);
    DECLARE v_flot_servi DECIMAL(15,2);
    DECLARE v_flot_en_cours DECIMAL(15,2);
    DECLARE v_depots DECIMAL(15,2);
    DECLARE v_retraits DECIMAL(15,2);
    
    -- Calculer les valeurs
    SELECT COALESCE(SUM(capital_cash), 0) INTO v_solde_ant_total
    FROM shops WHERE id = p_shop_id;
    
    SELECT COALESCE(SUM(montant_net), 0) INTO v_depots
    FROM operations 
    WHERE shop_source_id = p_shop_id 
      AND type = 'depot'
      AND DATE(date_op) = p_date_rapport;
    
    SELECT COALESCE(SUM(montant_net), 0) INTO v_retraits
    FROM operations 
    WHERE shop_source_id = p_shop_id 
      AND type = 'retrait'
      AND DATE(date_op) = p_date_rapport;
    
    -- Insérer le rapport
    INSERT INTO rapports_cloture (
        shop_id, shop_designation, date_rapport,
        depots_clients, retraits_clients,
        genere_par, date_generation
    )
    SELECT 
        p_shop_id, designation, p_date_rapport,
        v_depots, v_retraits,
        p_genere_par, NOW()
    FROM shops WHERE id = p_shop_id
    ON DUPLICATE KEY UPDATE
        depots_clients = v_depots,
        retraits_clients = v_retraits,
        date_generation = NOW();
        
END //

DELIMITER ;

-- ========================================
-- TRIGGERS
-- ========================================

DELIMITER //

-- Trigger pour mettre à jour le solde client après une opération
CREATE TRIGGER trg_update_client_solde_after_operation
AFTER INSERT ON operations
FOR EACH ROW
BEGIN
    IF NEW.client_id IS NOT NULL THEN
        IF NEW.type = 'depot' THEN
            UPDATE clients 
            SET solde = solde + NEW.montant_net,
                last_modified_at = NOW()
            WHERE id = NEW.client_id;
        ELSEIF NEW.type = 'retrait' THEN
            UPDATE clients 
            SET solde = solde - NEW.montant_net,
                last_modified_at = NOW()
            WHERE id = NEW.client_id;
        END IF;
    END IF;
END //

-- Trigger pour mettre à jour le capital du shop après une opération
CREATE TRIGGER trg_update_shop_capital_after_operation
AFTER INSERT ON operations
FOR EACH ROW
BEGIN
    DECLARE v_montant DECIMAL(15,2);
    SET v_montant = NEW.montant_net;
    
    IF NEW.type = 'depot' THEN
        -- Augmenter le capital du shop
        IF NEW.mode_paiement = 'cash' THEN
            UPDATE shops SET capital_cash = capital_cash + v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'airtelMoney' THEN
            UPDATE shops SET capital_airtel_money = capital_airtel_money + v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'mPesa' THEN
            UPDATE shops SET capital_mpesa = capital_mpesa + v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'orangeMoney' THEN
            UPDATE shops SET capital_orange_money = capital_orange_money + v_montant WHERE id = NEW.shop_source_id;
        END IF;
    ELSEIF NEW.type = 'retrait' THEN
        -- Diminuer le capital du shop
        IF NEW.mode_paiement = 'cash' THEN
            UPDATE shops SET capital_cash = capital_cash - v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'airtelMoney' THEN
            UPDATE shops SET capital_airtel_money = capital_airtel_money - v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'mPesa' THEN
            UPDATE shops SET capital_mpesa = capital_mpesa - v_montant WHERE id = NEW.shop_source_id;
        ELSEIF NEW.mode_paiement = 'orangeMoney' THEN
            UPDATE shops SET capital_orange_money = capital_orange_money - v_montant WHERE id = NEW.shop_source_id;
        END IF;
    END IF;
    
    -- Recalculer le capital actuel
    UPDATE shops 
    SET capital_actuel = capital_cash + capital_airtel_money + capital_mpesa + capital_orange_money
    WHERE id = NEW.shop_source_id;
END //

DELIMITER ;

-- ========================================
-- INDEX SUPPLÉMENTAIRES POUR PERFORMANCE
-- ========================================

-- Index composites pour améliorer les performances des requêtes
CREATE INDEX idx_operations_shop_date ON operations(shop_source_id, date_op);
CREATE INDEX idx_operations_client_date ON operations(client_id, date_op);
CREATE INDEX idx_flots_shop_date ON flots(shop_source_id, date_envoi);
CREATE INDEX idx_flots_destination_date ON flots(shop_destination_id, date_envoi);

-- ========================================
-- FIN DU SCRIPT
-- ========================================
