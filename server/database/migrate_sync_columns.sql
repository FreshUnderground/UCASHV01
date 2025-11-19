-- ============================================================================
-- Migration des colonnes de synchronisation pour document_headers et cloture_caisse
-- Compatible avec MySQL 5.7+ et MariaDB 10.2+
-- Date: 2025-11-19
-- ============================================================================

USE `ucash_db`;

-- ============================================================================
-- MIGRATION: document_headers
-- ============================================================================

-- Étape 1: Ajouter les nouvelles colonnes si elles n'existent pas
ALTER TABLE `document_headers` 
ADD COLUMN `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification';

ALTER TABLE `document_headers`
ADD COLUMN `last_modified_by` VARCHAR(100) DEFAULT 'system' COMMENT 'Modifié par (username)';

-- Étape 2: Renommer is_modified en is_synced si nécessaire
ALTER TABLE `document_headers` 
CHANGE COLUMN `is_modified` `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec le serveur';

-- Étape 3: Renommer last_synced_at en synced_at si nécessaire
ALTER TABLE `document_headers`
CHANGE COLUMN `last_synced_at` `synced_at` DATETIME DEFAULT NULL COMMENT 'Date de dernière synchronisation';

-- Étape 4: Ajouter l'index de synchronisation
ALTER TABLE `document_headers`
ADD INDEX `idx_sync` (`is_synced`, `last_modified_at`);

-- ============================================================================
-- CRÉATION: cloture_caisse
-- ============================================================================

CREATE TABLE IF NOT EXISTS `cloture_caisse` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `shop_id` INT(11) NOT NULL COMMENT 'ID du shop',
  `date_cloture` DATE NOT NULL COMMENT 'Date de fin de journée',
  
  -- Montants SAISIS par l'agent (comptage physique)
  `solde_saisi_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_saisi_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_saisi_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_saisi_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_saisi_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  
  -- Montants CALCULÉS par le système
  `solde_calcule_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_calcule_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_calcule_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_calcule_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `solde_calcule_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  
  -- Écarts (différences entre saisi et calculé)
  `ecart_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `ecart_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `ecart_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `ecart_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `ecart_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  
  -- Métadonnées
  `cloture_par` VARCHAR(50) NOT NULL COMMENT 'Username de l\'agent',
  `date_enregistrement` DATETIME NOT NULL COMMENT 'Date/heure d\'enregistrement',
  `notes` TEXT DEFAULT NULL COMMENT 'Notes optionnelles',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Colonnes de synchronisation
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification',
  `last_modified_by` VARCHAR(100) DEFAULT 'system' COMMENT 'Modifié par (username)',
  `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec le serveur',
  `synced_at` DATETIME DEFAULT NULL COMMENT 'Date de dernière synchronisation',
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_cloture_shop_date` (`shop_id`, `date_cloture`),
  INDEX `idx_shop_id` (`shop_id`),
  INDEX `idx_date_cloture` (`date_cloture`),
  INDEX `idx_sync` (`is_synced`, `last_modified_at`),
  CONSTRAINT `fk_cloture_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Clôtures de caisse quotidiennes';

COMMIT;
