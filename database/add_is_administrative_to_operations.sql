-- Migration: Ajouter le champ is_administrative aux operations
-- Date: 2025-12-11
-- Description: Permet de marquer les flots administratifs qui créent des dettes mais n'impactent pas le cash

USE ucash_db;

-- Ajouter la colonne is_administrative à la table operations
ALTER TABLE operations 
ADD COLUMN is_administrative BOOLEAN DEFAULT FALSE AFTER synced_at;

-- Créer un index pour optimiser les requêtes
CREATE INDEX idx_operations_is_administrative ON operations(is_administrative);

-- Afficher les colonnes pour vérification
SHOW COLUMNS FROM operations LIKE 'is_administrative';

SELECT 'Migration terminée avec succès: is_administrative ajouté à la table operations' AS Status;
