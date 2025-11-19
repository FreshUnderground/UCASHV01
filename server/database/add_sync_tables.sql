-- ============================================================================
-- Ajout des tables document_headers et cloture_caisse avec colonnes de sync
-- Date: 2025-11-19
-- ============================================================================

USE `ucash_db`;

-- ============================================================================
-- TABLE: document_headers
-- Description: En-têtes personnalisés pour documents (reçus, PDF, rapports)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `document_headers` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `company_name` VARCHAR(255) NOT NULL COMMENT 'Nom de l\'entreprise',
  `company_slogan` VARCHAR(255) DEFAULT NULL COMMENT 'Slogan de l\'entreprise',
  `address` TEXT DEFAULT NULL COMMENT 'Adresse complète',
  `phone` VARCHAR(50) DEFAULT NULL COMMENT 'Téléphone',
  `email` VARCHAR(100) DEFAULT NULL COMMENT 'Email',
  `website` VARCHAR(255) DEFAULT NULL COMMENT 'Site web',
  `logo_path` VARCHAR(255) DEFAULT NULL COMMENT 'Chemin vers le logo',
  `tax_number` VARCHAR(100) DEFAULT NULL COMMENT 'Numéro fiscal',
  `registration_number` VARCHAR(100) DEFAULT NULL COMMENT 'Numéro d\'enregistrement',
  `is_active` TINYINT(1) DEFAULT 1 COMMENT 'Actif ou non',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  
  -- Colonnes de synchronisation
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification',
  `last_modified_by` VARCHAR(100) DEFAULT 'system' COMMENT 'Modifié par (username)',
  `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec le serveur',
  `synced_at` DATETIME DEFAULT NULL COMMENT 'Date de dernière synchronisation',
  
  PRIMARY KEY (`id`),
  INDEX `idx_active` (`is_active`),
  INDEX `idx_sync` (`is_synced`, `last_modified_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='En-têtes personnalisés pour documents';

-- ============================================================================
-- TABLE: cloture_caisse
-- Description: Clôtures de caisse quotidiennes par shop
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

-- ============================================================================
-- Mise à jour de la table document_headers si elle existe déjà
-- ============================================================================

-- Ajouter les colonnes de sync si elles n'existent pas
ALTER TABLE `document_headers` 
ADD COLUMN IF NOT EXISTS `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification',
ADD COLUMN IF NOT EXISTS `last_modified_by` VARCHAR(100) DEFAULT 'system' COMMENT 'Modifié par (username)',
ADD COLUMN IF NOT EXISTS `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec le serveur',
ADD COLUMN IF NOT EXISTS `synced_at` DATETIME DEFAULT NULL COMMENT 'Date de dernière synchronisation';

-- Ajouter l'index de sync si il n'existe pas
ALTER TABLE `document_headers`
ADD INDEX IF NOT EXISTS `idx_sync` (`is_synced`, `last_modified_at`);

COMMIT;
