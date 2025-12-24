-- Script SQL simple pour ajouter les champs de soft delete
-- à la table triangular_debt_settlements

ALTER TABLE `triangular_debt_settlements` 
ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0,
ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL,
ADD COLUMN `deleted_by` VARCHAR(100) NULL DEFAULT NULL,
ADD COLUMN `delete_reason` TEXT NULL DEFAULT NULL;
