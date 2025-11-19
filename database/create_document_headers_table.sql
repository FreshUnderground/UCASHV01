-- Table pour les en-têtes personnalisés des documents (reçus, PDF, rapports)
CREATE TABLE IF NOT EXISTS `document_headers` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `company_name` VARCHAR(255) NOT NULL COMMENT 'Nom de l''entreprise',
  `company_slogan` VARCHAR(500) NULL COMMENT 'Slogan ou devise de l''entreprise',
  `address` TEXT NULL COMMENT 'Adresse complète',
  `phone` VARCHAR(50) NULL COMMENT 'Numéro de téléphone',
  `email` VARCHAR(100) NULL COMMENT 'Adresse email',
  `website` VARCHAR(200) NULL COMMENT 'Site web',
  `logo_path` VARCHAR(500) NULL COMMENT 'Chemin vers le logo de l''entreprise',
  `tax_number` VARCHAR(100) NULL COMMENT 'Numéro fiscal / TVA',
  `registration_number` VARCHAR(100) NULL COMMENT 'Numéro d''enregistrement commercial',
  `is_active` TINYINT(1) DEFAULT 1 COMMENT 'En-tête actif (1) ou inactif (0)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec les clients',
  `is_modified` TINYINT(1) DEFAULT 0 COMMENT 'Modifié depuis dernière sync',
  `last_synced_at` DATETIME NULL COMMENT 'Date de dernière synchronisation',
  INDEX `idx_is_active` (`is_active`),
  INDEX `idx_is_synced` (`is_synced`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='En-têtes personnalisés pour les documents (reçus, PDF, rapports)';

-- Insérer un en-tête par défaut
INSERT INTO `document_headers` (
  `company_name`,
  `company_slogan`,
  `address`,
  `phone`,
  `email`,
  `website`,
  `is_active`
) VALUES (
  'UCASH',
  'Votre partenaire de confiance',
  '',
  '',
  '',
  '',
  1
) ON DUPLICATE KEY UPDATE `id` = `id`;
