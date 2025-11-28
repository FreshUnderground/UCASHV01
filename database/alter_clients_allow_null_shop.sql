-- ========================================
-- Migration: Permettre shop_id NULL pour les clients admin
-- Date: 2024-11-28
-- ========================================

-- Désactiver temporairement les foreign keys pour modification
SET FOREIGN_KEY_CHECKS = 0;

-- Modifier la colonne shop_id pour permettre NULL
ALTER TABLE clients 
MODIFY COLUMN shop_id INT NULL 
COMMENT 'ID du shop de création (NULL pour clients admin globaux)';

-- Réactiver les foreign keys
SET FOREIGN_KEY_CHECKS = 1;

-- Vérifier la modification
DESCRIBE clients;

-- Message de confirmation
SELECT 'Migration terminée: shop_id peut maintenant être NULL pour les clients admin' AS status;
