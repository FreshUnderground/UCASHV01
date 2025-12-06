-- ============================================================================
-- OPTIMISATION DES INDEX POUR LES FLOTS
-- Date: 2025-12-06
-- Description: Ajoute des index pour améliorer les performances des requêtes FLOT
-- ============================================================================

-- Index pour le type d'opération (permet filtrage rapide par type)
-- Utilisé par: WHERE type = 'flotShopToShop'
CREATE INDEX IF NOT EXISTS idx_operations_type ON operations(type);

-- Index composite pour les requêtes FLOT par shop et type
-- Utilisé par: WHERE type = 'flotShopToShop' AND (shop_source_id = X OR shop_destination_id = X)
CREATE INDEX IF NOT EXISTS idx_operations_type_shop_source ON operations(type, shop_source_id);
CREATE INDEX IF NOT EXISTS idx_operations_type_shop_dest ON operations(type, shop_destination_id);

-- Index composite pour les requêtes FLOT avec statut
-- Utilisé par: WHERE type = 'flotShopToShop' AND statut = 'enAttente'
CREATE INDEX IF NOT EXISTS idx_operations_type_statut ON operations(type, statut);

-- Index pour le filtrage par date et type (sync des 4 derniers jours)
CREATE INDEX IF NOT EXISTS idx_operations_type_created_at ON operations(type, created_at DESC);

-- ============================================================================
-- VÉRIFICATION DES INDEX
-- ============================================================================

-- Afficher les index créés pour la table operations
SHOW INDEX FROM operations WHERE Key_name LIKE '%type%';

-- ============================================================================
-- ANALYSE DES PERFORMANCES
-- ============================================================================

-- Analyser les performances de la table après ajout des index
ANALYZE TABLE operations;

-- Test: Vérifier que l'index type est utilisé
EXPLAIN SELECT * FROM operations WHERE type = 'flotShopToShop' LIMIT 10;

-- Test: Vérifier l'index composite type + shop
EXPLAIN SELECT * FROM operations 
WHERE type = 'flotShopToShop' 
AND (shop_source_id = 1 OR shop_destination_id = 1)
LIMIT 10;

-- Test: Vérifier l'index pour les FLOTs en attente
EXPLAIN SELECT * FROM operations 
WHERE type = 'flotShopToShop' 
AND statut = 'enAttente'
AND created_at >= DATE_SUB(NOW(), INTERVAL 4 DAY)
LIMIT 10;

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================

SELECT '✅ Index FLOT créés avec succès!' AS Status;
