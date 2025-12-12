-- ========================================================================
-- MIGRATION: Ajouter is_administrative aux transactions virtuelles
-- ========================================================================
-- Description: Permet de créer des transactions virtuelles administratives
--              qui ne doivent pas impacter le cash disponible
-- Date: 2025-12-12
-- ========================================================================

USE ucash_db;

-- Ajouter la colonne is_administrative
ALTER TABLE virtual_transactions 
ADD COLUMN is_administrative BOOLEAN DEFAULT FALSE 
AFTER synced_at;

-- Créer un index pour optimiser les requêtes
CREATE INDEX idx_virtual_transactions_is_administrative 
ON virtual_transactions(is_administrative);

-- Vérifier que la colonne a été créée
SHOW COLUMNS FROM virtual_transactions LIKE 'is_administrative';

-- Afficher quelques statistiques
SELECT 
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_administrative = 1 THEN 1 ELSE 0 END) as transactions_administratives,
    SUM(CASE WHEN is_administrative = 0 THEN 1 ELSE 0 END) as transactions_normales
FROM virtual_transactions;

-- ========================================================================
-- FIN DE LA MIGRATION
-- ========================================================================
