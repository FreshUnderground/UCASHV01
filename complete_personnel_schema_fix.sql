-- Script complet pour corriger tous les problèmes de schéma personnel
-- À exécuter dans phpMyAdmin en une seule fois

-- 1. Ajouter toutes les colonnes manquantes
ALTER TABLE `personnel` 
ADD COLUMN IF NOT EXISTS `mode_paiement` varchar(50) DEFAULT 'Especes' COMMENT 'Mode de paiement du salaire' 
AFTER `devise_salaire`;

ALTER TABLE `personnel` 
ADD COLUMN IF NOT EXISTS `motif_depart` varchar(255) DEFAULT NULL COMMENT 'Motif de départ si applicable' 
AFTER `statut`;

ALTER TABLE `personnel` 
ADD COLUMN IF NOT EXISTS `date_depart` date DEFAULT NULL COMMENT 'Date de départ si applicable' 
AFTER `motif_depart`;

ALTER TABLE `personnel` 
ADD COLUMN IF NOT EXISTS `notes` text DEFAULT NULL COMMENT 'Notes additionnelles' 
AFTER `date_depart`;

ALTER TABLE `personnel` 
ADD COLUMN IF NOT EXISTS `deleted_at` datetime DEFAULT NULL COMMENT 'Date de suppression logique' 
AFTER `synced_at`;

-- 2. Ajouter les index manquants
ALTER TABLE `personnel` 
ADD KEY IF NOT EXISTS `idx_deleted_at` (`deleted_at`);

ALTER TABLE `personnel` 
ADD KEY IF NOT EXISTS `idx_mode_paiement` (`mode_paiement`);

-- 3. Vérifier la structure finale
DESCRIBE personnel;

-- 4. Insérer un enregistrement de test pour vérifier la synchronisation
INSERT IGNORE INTO personnel (
    matricule, nom, prenom, telephone, poste, date_embauche, 
    salaire_base, devise_salaire, mode_paiement, statut,
    is_synced, created_at, last_modified_at
) VALUES (
    'SYNC_TEST_001', 'Test', 'Synchronisation', '+243999999999', 'Agent Test Sync', 
    CURDATE(), 150.00, 'USD', 'Especes', 'Actif',
    0, NOW(), NOW()
);

-- 5. Vérifier que l'enregistrement de test a été créé
SELECT 
    matricule, nom, prenom, poste, mode_paiement, 
    is_synced, created_at, last_modified_at 
FROM personnel 
WHERE matricule = 'SYNC_TEST_001';
