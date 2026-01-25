-- Script pour ajouter les colonnes manquantes dans la table personnel
-- À exécuter dans phpMyAdmin

-- 1. Ajouter la colonne mode_paiement manquante
ALTER TABLE `personnel` 
ADD COLUMN `mode_paiement` varchar(50) DEFAULT 'Especes' COMMENT 'Mode de paiement du salaire' 
AFTER `devise_salaire`;

-- 2. Ajouter les autres colonnes manquantes identifiées dans l'API
ALTER TABLE `personnel` 
ADD COLUMN `motif_depart` varchar(255) DEFAULT NULL COMMENT 'Motif de départ si applicable' 
AFTER `statut`;

ALTER TABLE `personnel` 
ADD COLUMN `date_depart` date DEFAULT NULL COMMENT 'Date de départ si applicable' 
AFTER `motif_depart`;

ALTER TABLE `personnel` 
ADD COLUMN `notes` text DEFAULT NULL COMMENT 'Notes additionnelles' 
AFTER `date_depart`;

-- 3. Vérifier que toutes les colonnes existent maintenant
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'inves2504808_18xpitt' 
AND TABLE_NAME = 'personnel'
AND COLUMN_NAME IN ('mode_paiement', 'motif_depart', 'date_depart', 'notes', 'deleted_at')
ORDER BY COLUMN_NAME;
