-- Migration: Ajouter le type 'flotShopToShop' à la table operations
-- Date: 2025-11-27
-- Description: Permet d'utiliser la table operations pour gérer les FLOTs (transferts de liquidité entre shops)
--              au lieu d'avoir une table séparée. Facilite la synchronisation unifiée.

USE ucash_db;

-- Modifier le type ENUM pour inclure 'flotShopToShop'
ALTER TABLE operations 
MODIFY COLUMN type ENUM(
    'transfertNational', 
    'transfertInternationalSortant', 
    'transfertInternationalEntrant', 
    'depot', 
    'retrait', 
    'virement', 
    'retraitMobileMoney',
    'flotShopToShop'  -- NOUVEAU: Transfert de liquidité shop-to-shop (commission = 0)
) NOT NULL;

-- Vérifier le résultat
DESCRIBE operations;

-- Afficher les types d'opération possibles
SELECT COLUMN_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'operations' 
  AND COLUMN_NAME = 'type' 
  AND TABLE_SCHEMA = 'ucash_db';

-- Exemple de comment créer un FLOT shop-to-shop:
-- INSERT INTO operations (
--   type, code_ops, 
--   shop_source_id, shop_source_designation,
--   shop_destination_id, shop_destination_designation,
--   agent_id, agent_username,
--   montant_brut, montant_net, commission,
--   mode_paiement, statut, devise,
--   created_at, last_modified_at, last_modified_by
-- ) VALUES (
--   'flotShopToShop', 'FLOT123456',
--   1, 'Shop A',  -- Source
--   2, 'Shop B',  -- Destination
--   1, 'admin',
--   1000.00, 1000.00, 0.00,  -- Commission = 0 pour les FLOTs
--   'cash', 'enAttente', 'USD',
--   NOW(), NOW(), 'admin'
-- );
