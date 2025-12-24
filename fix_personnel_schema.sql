-- Script de correction du schéma personnel pour la synchronisation
-- À exécuter dans phpMyAdmin pour corriger les problèmes identifiés

-- 1. Ajouter la colonne deleted_at manquante à la table personnel
ALTER TABLE `personnel` 
ADD COLUMN `deleted_at` datetime DEFAULT NULL COMMENT 'Date de suppression logique' 
AFTER `synced_at`;

-- 2. Ajouter l'index pour deleted_at
ALTER TABLE `personnel` 
ADD KEY `idx_deleted_at` (`deleted_at`);

-- 3. Ajouter les colonnes deleted_at aux tables liées si elles n'existent pas

-- Table salaires
ALTER TABLE `salaires` 
ADD COLUMN `deleted_at` datetime DEFAULT NULL COMMENT 'Date de suppression logique' 
AFTER `synced_at`;

ALTER TABLE `salaires` 
ADD KEY `idx_salaires_deleted_at` (`deleted_at`);

-- Table avances_personnel
ALTER TABLE `avances_personnel` 
ADD COLUMN `deleted_at` datetime DEFAULT NULL COMMENT 'Date de suppression logique' 
AFTER `synced_at`;

ALTER TABLE `avances_personnel` 
ADD KEY `idx_avances_deleted_at` (`deleted_at`);

-- Table retenues_personnel
ALTER TABLE `retenues_personnel` 
ADD COLUMN `deleted_at` datetime DEFAULT NULL COMMENT 'Date de suppression logique' 
AFTER `synced_at`;

ALTER TABLE `retenues_personnel` 
ADD KEY `idx_retenues_deleted_at` (`deleted_at`);

-- 4. Vérifier que toutes les colonnes existent maintenant
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'inves2504808_1n6a7b' 
AND TABLE_NAME IN ('personnel', 'salaires', 'avances_personnel', 'retenues_personnel')
AND COLUMN_NAME IN ('deleted_at', 'numero_inss', 'synced_at', 'is_synced')
ORDER BY TABLE_NAME, COLUMN_NAME;
