-- ============================================================================
-- FIX: Corriger les IDs tronqués à 2147483647
-- À exécuter APRÈS avoir converti les colonnes en BIGINT
-- ============================================================================

-- ATTENTION: Ce script supprime les données tronquées car on ne peut pas
-- retrouver les IDs originaux. Vous devrez recréer ces entités depuis l'app.

-- ============================================================================
-- SHOPS TRONQUÉS
-- ============================================================================
-- Afficher les shops avec IDs tronqués
SELECT 'Shops avec IDs tronqués:' AS info;
SELECT id, designation, localisation 
FROM shops 
WHERE id = 2147483647;

-- OPTION 1: Supprimer les shops tronqués (À FAIRE MANUELLEMENT)
-- DELETE FROM shops WHERE id = 2147483647;

-- OPTION 2: Les garder avec un nouvel ID (RECOMMANDÉ)
-- Vous devrez les recréer dans l'app pour avoir les bons IDs

-- ============================================================================
-- COMMISSIONS TRONQUÉES
-- ============================================================================
-- Afficher les commissions avec shop_source_id tronqués
SELECT 'Commissions avec shop_source_id tronqués:' AS info;
SELECT id, description, shop_source_id, shop_destination_id, taux 
FROM commissions 
WHERE shop_source_id = 2147483647 OR shop_destination_id = 2147483647;

-- Supprimer les commissions invalides (shop IDs tronqués)
DELETE FROM commissions 
WHERE shop_source_id = 2147483647 OR shop_destination_id = 2147483647;

SELECT '✅ Commissions avec IDs tronqués supprimées' AS status;

-- ============================================================================
-- AGENTS TRONQUÉS
-- ============================================================================
SELECT 'Agents avec shop_id tronqués:' AS info;
SELECT id, username, shop_id 
FROM agents 
WHERE shop_id = 2147483647;

-- ============================================================================
-- OPERATIONS TRONQUÉES
-- ============================================================================
SELECT 'Opérations avec shop_id tronqués:' AS info;
SELECT id, code_ops, shop_source_id, shop_destination_id 
FROM operations 
WHERE shop_source_id = 2147483647 OR shop_destination_id = 2147483647;

-- ============================================================================
-- RÉSUMÉ
-- ============================================================================
SELECT '⚠️ ATTENTION: Les entités avec IDs tronqués doivent être recréées dans l\'app!' AS warning;
SELECT 'Les commissions invalides ont été supprimées.' AS info;
SELECT 'Recréez les shops, agents et commissions depuis l\'application mobile.' AS action;
