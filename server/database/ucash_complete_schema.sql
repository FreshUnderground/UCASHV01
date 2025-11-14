-- ============================================================================
-- UCASH V01 - Base de Données Complète
-- Système de gestion de transactions financières multi-devises
-- Date: 2025-11-09
-- Version: 1.0
-- ============================================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

-- ============================================================================
-- CRÉATION DE LA BASE DE DONNÉES
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `ucash_db` 
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `ucash_db`;

-- ============================================================================
-- TABLE: users
-- Description: Gestion des utilisateurs administrateurs et comptables
-- ============================================================================

CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('admin','comptable','agent') DEFAULT 'agent',
  `nom` varchar(100) DEFAULT NULL,
  `prenom` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `telephone` varchar(20) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `idx_role` (`role`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: shops
-- Description: Gestion des boutiques/agences avec support multi-devises
-- ============================================================================

CREATE TABLE IF NOT EXISTS `shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nom` varchar(100) NOT NULL,
  `adresse` varchar(255) DEFAULT NULL,
  `telephone` varchar(20) DEFAULT NULL,
  `ville` varchar(100) DEFAULT NULL,
  `pays` varchar(100) DEFAULT 'RDC',
  
  -- Capital en devise principale (USD)
  `capital_initial` decimal(15,2) DEFAULT 0.00,
  `capital_actuel` decimal(15,2) DEFAULT 0.00,
  `capital_cash` decimal(15,2) DEFAULT 0.00,
  `capital_airtel_money` decimal(15,2) DEFAULT 0.00,
  `capital_mpesa` decimal(15,2) DEFAULT 0.00,
  `capital_orange_money` decimal(15,2) DEFAULT 0.00,
  
  -- Support multi-devises
  `devise_principale` varchar(10) DEFAULT 'USD',
  `devise_secondaire` varchar(10) DEFAULT NULL,
  
  -- Capital en devise secondaire (CDF/UGX)
  `capital_initial_devise2` decimal(15,2) DEFAULT 0.00,
  `capital_actuel_devise2` decimal(15,2) DEFAULT 0.00,
  `capital_cash_devise2` decimal(15,2) DEFAULT 0.00,
  `capital_airtel_money_devise2` decimal(15,2) DEFAULT 0.00,
  `capital_mpesa_devise2` decimal(15,2) DEFAULT 0.00,
  `capital_orange_money_devise2` decimal(15,2) DEFAULT 0.00,
  
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_active` (`is_active`),
  KEY `idx_ville` (`ville`),
  KEY `idx_devise` (`devise_principale`,`devise_secondaire`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: agents
-- Description: Gestion des agents par boutique
-- ============================================================================

CREATE TABLE IF NOT EXISTS `agents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `nom` varchar(100) NOT NULL,
  `prenom` varchar(100) DEFAULT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `telephone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `adresse` varchar(255) DEFAULT NULL,
  `commission_rate` decimal(5,2) DEFAULT 0.00 COMMENT 'Taux de commission en %',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_active` (`is_active`),
  CONSTRAINT `fk_agent_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: clients
-- Description: Gestion des clients par boutique avec compte multi-devises
-- ============================================================================

CREATE TABLE IF NOT EXISTS `clients` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `nom` varchar(100) NOT NULL,
  `telephone` varchar(20) NOT NULL,
  `adresse` varchar(255) DEFAULT NULL,
  `username` varchar(50) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  
  -- Numéro de compte unique
  `numero_compte` varchar(20) DEFAULT NULL,
  
  -- Solde en devise principale (USD)
  `solde` decimal(15,2) DEFAULT 0.00,
  
  -- Solde en devise secondaire (CDF/UGX)
  `solde_devise2` decimal(15,2) DEFAULT 0.00,
  
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_modified_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` int(11) DEFAULT NULL COMMENT 'ID de l\'agent qui a modifié',
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_shop_phone` (`shop_id`,`telephone`),
  UNIQUE KEY `unique_numero_compte` (`numero_compte`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_active` (`is_active`),
  KEY `idx_nom` (`nom`),
  CONSTRAINT `fk_client_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: operations
-- Description: Toutes les opérations (dépôts, retraits, transferts)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `operations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reference` varchar(50) NOT NULL,
  `type` enum('depot','retrait','transfert_national','transfert_international_sortant','transfert_international_entrant') NOT NULL,
  `shop_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `client_id` int(11) DEFAULT NULL COMMENT 'Client pour dépôt/retrait',
  
  -- Montants et devise
  `montant_brut` decimal(15,2) NOT NULL,
  `commission` decimal(15,2) DEFAULT 0.00,
  `montant_net` decimal(15,2) NOT NULL,
  `devise` varchar(10) DEFAULT 'USD',
  
  -- Mode de paiement
  `mode_paiement` enum('cash','airtel_money','mpesa','orange_money') NOT NULL DEFAULT 'cash',
  
  -- Informations transfert
  `destinataire` varchar(100) DEFAULT NULL,
  `telephone_destinataire` varchar(20) DEFAULT NULL,
  `pays_destination` varchar(100) DEFAULT NULL,
  `ville_destination` varchar(100) DEFAULT NULL,
  `shop_destination_id` int(11) DEFAULT NULL COMMENT 'Pour transferts inter-shops',
  
  -- Statut et validation
  `statut` enum('en_attente','validee','annulee','refusee') DEFAULT 'en_attente',
  `date_validation` timestamp NULL DEFAULT NULL,
  `validee_par` int(11) DEFAULT NULL COMMENT 'ID de l\'agent validateur',
  
  -- Preuve et commentaires
  `preuve_image` varchar(255) DEFAULT NULL,
  `commentaire` text DEFAULT NULL,
  
  -- Dates
  `date_operation` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Synchronisation
  `is_synced` tinyint(1) DEFAULT 0,
  `last_sync_at` timestamp NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `reference` (`reference`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_agent` (`agent_id`),
  KEY `idx_client` (`client_id`),
  KEY `idx_type` (`type`),
  KEY `idx_devise` (`devise`),
  KEY `idx_statut` (`statut`),
  KEY `idx_date_operation` (`date_operation`),
  KEY `idx_sync` (`is_synced`),
  CONSTRAINT `fk_operation_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_operation_agent` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_operation_client` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_operation_validateur` FOREIGN KEY (`validee_par`) REFERENCES `agents` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: taux_change
-- Description: Taux de change entre devises
-- ============================================================================

CREATE TABLE IF NOT EXISTS `taux_change` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) DEFAULT NULL COMMENT 'NULL = taux global',
  `devise_source` varchar(10) NOT NULL DEFAULT 'USD',
  `devise_cible` varchar(10) NOT NULL,
  `type` enum('ACHAT','VENTE','MOYEN') NOT NULL DEFAULT 'MOYEN',
  `taux` decimal(15,6) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `date_debut` date DEFAULT NULL,
  `date_fin` date DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_devises` (`devise_source`,`devise_cible`),
  KEY `idx_type` (`type`),
  KEY `idx_active` (`is_active`),
  CONSTRAINT `fk_taux_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: commissions
-- Description: Grille de commissions par type d'opération
-- ============================================================================

CREATE TABLE IF NOT EXISTS `commissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) DEFAULT NULL COMMENT 'NULL = commission globale',
  `type_operation` enum('depot','retrait','transfert_national','transfert_international_sortant','transfert_international_entrant') NOT NULL,
  `devise` varchar(10) DEFAULT 'USD',
  `montant_min` decimal(15,2) DEFAULT 0.00,
  `montant_max` decimal(15,2) DEFAULT NULL,
  `type_commission` enum('fixe','pourcentage') NOT NULL DEFAULT 'fixe',
  `valeur` decimal(15,6) NOT NULL COMMENT 'Montant fixe ou % selon type_commission',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_type_op` (`type_operation`),
  KEY `idx_devise` (`devise`),
  KEY `idx_active` (`is_active`),
  CONSTRAINT `fk_commission_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: journal_caisse
-- Description: Journal des mouvements de caisse
-- ============================================================================

CREATE TABLE IF NOT EXISTS `journal_caisse` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `operation_id` int(11) DEFAULT NULL,
  `type_mouvement` enum('entree','sortie','transfert_inter_shop','ajustement') NOT NULL,
  `montant` decimal(15,2) NOT NULL,
  `devise` varchar(10) DEFAULT 'USD',
  `mode_paiement` enum('cash','airtel_money','mpesa','orange_money') NOT NULL DEFAULT 'cash',
  `solde_avant` decimal(15,2) DEFAULT NULL,
  `solde_apres` decimal(15,2) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `date_mouvement` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_agent` (`agent_id`),
  KEY `idx_operation` (`operation_id`),
  KEY `idx_type` (`type_mouvement`),
  KEY `idx_devise` (`devise`),
  KEY `idx_date` (`date_mouvement`),
  CONSTRAINT `fk_journal_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_journal_agent` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_journal_operation` FOREIGN KEY (`operation_id`) REFERENCES `operations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: sync_operations
-- Description: Suivi de la synchronisation des opérations
-- ============================================================================

CREATE TABLE IF NOT EXISTS `sync_operations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `operation_id` int(11) NOT NULL,
  `shop_id` int(11) NOT NULL,
  `action` enum('create','update','delete') NOT NULL,
  `data` text DEFAULT NULL COMMENT 'JSON des données',
  `status` enum('pending','synced','failed') DEFAULT 'pending',
  `error_message` text DEFAULT NULL,
  `attempt_count` int(11) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `synced_at` timestamp NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  KEY `idx_operation` (`operation_id`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: sync_shops
-- Description: Suivi de la synchronisation des shops
-- ============================================================================

CREATE TABLE IF NOT EXISTS `sync_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `shop_id` int(11) NOT NULL,
  `action` enum('create','update','delete') NOT NULL,
  `data` text DEFAULT NULL COMMENT 'JSON des données',
  `status` enum('pending','synced','failed') DEFAULT 'pending',
  `error_message` text DEFAULT NULL,
  `attempt_count` int(11) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `synced_at` timestamp NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DONNÉES INITIALES
-- ============================================================================

-- Administrateur par défaut
INSERT INTO `users` (`username`, `password`, `role`, `nom`, `prenom`, `email`) VALUES
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'Administrateur', 'Système', 'admin@ucash.cd');
-- Mot de passe: password


-- ============================================================================
-- VUES UTILES
-- ============================================================================

-- Vue des statistiques par shop
CREATE OR REPLACE VIEW `v_shop_stats` AS
SELECT 
    s.id AS shop_id,
    s.nom AS shop_nom,
    s.ville,
    s.devise_principale,
    s.devise_secondaire,
    s.capital_actuel AS capital_usd,
    s.capital_actuel_devise2 AS capital_devise2,
    COUNT(DISTINCT a.id) AS nb_agents,
    COUNT(DISTINCT c.id) AS nb_clients,
    COUNT(DISTINCT o.id) AS nb_operations,
    SUM(CASE WHEN o.devise = s.devise_principale THEN o.montant_brut ELSE 0 END) AS volume_usd,
    SUM(CASE WHEN o.devise = s.devise_secondaire THEN o.montant_brut ELSE 0 END) AS volume_devise2,
    SUM(CASE WHEN o.devise = s.devise_principale THEN o.commission ELSE 0 END) AS commissions_usd,
    SUM(CASE WHEN o.devise = s.devise_secondaire THEN o.commission ELSE 0 END) AS commissions_devise2
FROM shops s
LEFT JOIN agents a ON s.id = a.shop_id AND a.is_active = 1
LEFT JOIN clients c ON s.id = c.shop_id AND c.is_active = 1
LEFT JOIN operations o ON s.id = o.shop_id AND o.statut = 'validee'
WHERE s.is_active = 1
GROUP BY s.id;

-- Vue des opérations du jour
CREATE OR REPLACE VIEW `v_operations_today` AS
SELECT 
    o.*,
    s.nom AS shop_nom,
    a.nom AS agent_nom,
    c.nom AS client_nom
FROM operations o
INNER JOIN shops s ON o.shop_id = s.id
INNER JOIN agents a ON o.agent_id = a.id
LEFT JOIN clients c ON o.client_id = c.id
WHERE DATE(o.date_operation) = CURDATE()
ORDER BY o.date_operation DESC;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DELIMITER $$

-- Trigger: Mise à jour du capital shop après opération
CREATE TRIGGER `trg_operation_update_capital` AFTER INSERT ON `operations`
FOR EACH ROW
BEGIN
    IF NEW.statut = 'validee' THEN
        -- Logique de mise à jour du capital selon le type d'opération
        -- Cette logique est simplifiée, adaptez selon vos besoins
        
        IF NEW.type = 'depot' THEN
            IF NEW.devise = 'USD' THEN
                UPDATE shops SET 
                    capital_actuel = capital_actuel + NEW.montant_net,
                    capital_cash = CASE WHEN NEW.mode_paiement = 'cash' THEN capital_cash + NEW.montant_net ELSE capital_cash END,
                    capital_airtel_money = CASE WHEN NEW.mode_paiement = 'airtel_money' THEN capital_airtel_money + NEW.montant_net ELSE capital_airtel_money END,
                    capital_mpesa = CASE WHEN NEW.mode_paiement = 'mpesa' THEN capital_mpesa + NEW.montant_net ELSE capital_mpesa END,
                    capital_orange_money = CASE WHEN NEW.mode_paiement = 'orange_money' THEN capital_orange_money + NEW.montant_net ELSE capital_orange_money END
                WHERE id = NEW.shop_id;
            ELSE
                UPDATE shops SET 
                    capital_actuel_devise2 = capital_actuel_devise2 + NEW.montant_net,
                    capital_cash_devise2 = CASE WHEN NEW.mode_paiement = 'cash' THEN capital_cash_devise2 + NEW.montant_net ELSE capital_cash_devise2 END,
                    capital_airtel_money_devise2 = CASE WHEN NEW.mode_paiement = 'airtel_money' THEN capital_airtel_money_devise2 + NEW.montant_net ELSE capital_airtel_money_devise2 END,
                    capital_mpesa_devise2 = CASE WHEN NEW.mode_paiement = 'mpesa' THEN capital_mpesa_devise2 + NEW.montant_net ELSE capital_mpesa_devise2 END,
                    capital_orange_money_devise2 = CASE WHEN NEW.mode_paiement = 'orange_money' THEN capital_orange_money_devise2 + NEW.montant_net ELSE capital_orange_money_devise2 END
                WHERE id = NEW.shop_id;
            END IF;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- INDEX DE PERFORMANCE
-- ============================================================================

-- Index composites pour requêtes fréquentes
CREATE INDEX idx_operations_shop_date ON operations(shop_id, date_operation DESC);
CREATE INDEX idx_operations_agent_date ON operations(agent_id, date_operation DESC);
CREATE INDEX idx_operations_client_date ON operations(client_id, date_operation DESC);
CREATE INDEX idx_operations_devise_statut ON operations(devise, statut);

-- Index pour le journal de caisse
CREATE INDEX idx_journal_shop_date_devise ON journal_caisse(shop_id, date_mouvement, devise);
CREATE INDEX idx_journal_agent_date ON journal_caisse(agent_id, date_mouvement);

-- ============================================================================
-- PROCÉDURES STOCKÉES
-- ============================================================================

DELIMITER $$

-- Procédure: Calculer le solde client
CREATE PROCEDURE `sp_calculate_client_balance`(IN p_client_id INT, IN p_devise VARCHAR(10))
BEGIN
    DECLARE v_solde DECIMAL(15,2);
    
    SELECT 
        COALESCE(SUM(CASE 
            WHEN type = 'depot' THEN montant_net 
            WHEN type = 'retrait' THEN -montant_net 
            ELSE 0 
        END), 0)
    INTO v_solde
    FROM operations
    WHERE client_id = p_client_id 
        AND devise = p_devise 
        AND statut = 'validee';
    
    IF p_devise = 'USD' THEN
        UPDATE clients SET solde = v_solde WHERE id = p_client_id;
    ELSE
        UPDATE clients SET solde_devise2 = v_solde WHERE id = p_client_id;
    END IF;
END$$

-- Procédure: Rapport quotidien shop
CREATE PROCEDURE `sp_daily_shop_report`(IN p_shop_id INT, IN p_date DATE)
BEGIN
    SELECT 
        COUNT(*) AS total_operations,
        SUM(CASE WHEN type = 'depot' THEN 1 ELSE 0 END) AS nb_depots,
        SUM(CASE WHEN type = 'retrait' THEN 1 ELSE 0 END) AS nb_retraits,
        SUM(CASE WHEN type LIKE 'transfert%' THEN 1 ELSE 0 END) AS nb_transferts,
        SUM(CASE WHEN devise = 'USD' THEN montant_brut ELSE 0 END) AS volume_usd,
        SUM(CASE WHEN devise = 'CDF' THEN montant_brut ELSE 0 END) AS volume_cdf,
        SUM(CASE WHEN devise = 'USD' THEN commission ELSE 0 END) AS commissions_usd,
        SUM(CASE WHEN devise = 'CDF' THEN commission ELSE 0 END) AS commissions_cdf
    FROM operations
    WHERE shop_id = p_shop_id 
        AND DATE(date_operation) = p_date
        AND statut = 'validee';
END$$

DELIMITER ;

-- ============================================================================
-- PERMISSIONS ET SÉCURITÉ
-- ============================================================================

-- Créer un utilisateur applicatif (OPTIONNEL - à adapter selon votre configuration)
-- CREATE USER 'ucash_app'@'localhost' IDENTIFIED BY 'VotreMotDePasseSecurise';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ucash_db.* TO 'ucash_app'@'localhost';
-- FLUSH PRIVILEGES;

COMMIT;

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================
