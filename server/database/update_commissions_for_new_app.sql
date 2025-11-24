-- Migration de la table commissions pour la nouvelle structure app
-- Date: 2025-11-23
-- Compatible avec le nouveau système de commissions SORTANT/ENTRANT avec shop routing

-- 1. Créer la nouvelle table commissions avec la structure attendue par l'app
DROP TABLE IF EXISTS `commissions_new`;
CREATE TABLE `commissions_new` (
  `id` BIGINT NOT NULL COMMENT 'ID généré par l\'app (timestamp)',
  `type` ENUM('SORTANT', 'ENTRANT') NOT NULL COMMENT 'Type de commission',
  `taux` DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT 'Taux en pourcentage',
  `description` VARCHAR(255) NOT NULL COMMENT 'Description de la commission',
  `shop_id` INT(11) DEFAULT NULL COMMENT 'Shop spécifique (NULL = général)',
  `shop_source_id` INT(11) DEFAULT NULL COMMENT 'Shop source pour route shop-to-shop',
  `shop_destination_id` INT(11) DEFAULT NULL COMMENT 'Shop destination pour route shop-to-shop',
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `last_modified_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(50) DEFAULT 'SYSTEM',
  `is_synced` TINYINT(1) DEFAULT 1 COMMENT 'Statut de synchronisation',
  `synced_at` TIMESTAMP NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  KEY `idx_type` (`type`),
  KEY `idx_shop` (`shop_id`),
  KEY `idx_shop_source` (`shop_source_id`),
  KEY `idx_shop_destination` (`shop_destination_id`),
  KEY `idx_source_dest` (`shop_source_id`, `shop_destination_id`, `type`),
  KEY `idx_sync` (`is_synced`),
  
  CONSTRAINT `fk_commission_shop_new` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_commission_source_new` FOREIGN KEY (`shop_source_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_commission_dest_new` FOREIGN KEY (`shop_destination_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Migrer les données existantes (si nécessaire)
-- Cette section dépend de vos données existantes
-- Pour l'instant, nous créons juste les commissions par défaut

-- 3. Renommer l'ancienne table
DROP TABLE IF EXISTS `commissions_old`;
RENAME TABLE `commissions` TO `commissions_old`;

-- 4. Renommer la nouvelle table
RENAME TABLE `commissions_new` TO `commissions`;

-- 5. Insérer les commissions par défaut
INSERT INTO `commissions` (`id`, `type`, `taux`, `description`, `shop_id`, `shop_source_id`, `shop_destination_id`, `is_active`, `last_modified_by`, `is_synced`, `synced_at`) VALUES
(1732366000000, 'SORTANT', 2.00, 'Commission générale pour transferts sortants (RDC vers étranger)', NULL, NULL, NULL, 1, 'SYSTEM', 1, NOW()),
(1732366000001, 'ENTRANT', 0.00, 'Transferts entrants vers RDC - GRATUIT', NULL, NULL, NULL, 1, 'SYSTEM', 1, NOW());

-- Notification
SELECT 'Table commissions migrée avec succès!' AS message;
SELECT 'L\'ancienne table a été renommée en commissions_old pour sauvegarde' AS message;
SELECT 'Vous pouvez la supprimer avec: DROP TABLE commissions_old;' AS message;
