-- Migration pour ajouter les champs de suppression douce (soft delete)
-- à la table triangular_debt_settlements
-- 
-- Exécuter ce script sur la base de données MySQL
-- Date: 2025-12-21

USE ucash_db;

-- Ajouter les colonnes de soft delete à la table triangular_debt_settlements
ALTER TABLE `triangular_debt_settlements` 
ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Indicateur de suppression douce (0=actif, 1=supprimé)',
ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL COMMENT 'Date et heure de suppression',
ADD COLUMN `deleted_by` VARCHAR(100) NULL DEFAULT NULL COMMENT 'Utilisateur qui a effectué la suppression',
ADD COLUMN `delete_reason` TEXT NULL DEFAULT NULL COMMENT 'Raison de la suppression';

-- Ajouter un index sur is_deleted pour optimiser les requêtes
CREATE INDEX `idx_triangular_debt_settlements_is_deleted` ON `triangular_debt_settlements` (`is_deleted`);

-- Ajouter un index composé pour les requêtes de synchronisation
CREATE INDEX `idx_triangular_debt_settlements_sync_delete` ON `triangular_debt_settlements` (`last_modified_at`, `is_deleted`);

-- Vérifier la structure de la table après modification
DESCRIBE `triangular_debt_settlements`;

-- Afficher un message de confirmation
SELECT 'Migration terminée: Champs de soft delete ajoutés à triangular_debt_settlements' AS status;
