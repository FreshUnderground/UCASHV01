-- ============================================================================
-- UCASH - Optimisation des Index MySQL pour la Synchronisation
-- ============================================================================
-- Ce script ajoute des index composites pour améliorer les performances
-- des requêtes de synchronisation
-- ============================================================================

-- Vérifier la base de données
USE inves2504808_6oor7p;

-- ============================================================================
-- TABLE: operations
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
-- Utilisé par: WHERE last_modified_at > ? AND is_synced = ?
CREATE INDEX IF NOT EXISTS idx_operations_sync 
ON operations(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de filtrage par shop
-- ----------------------------------------------------------------------------
-- Utilisé par: WHERE shop_source_id = ? OR shop_destination_id = ?
CREATE INDEX IF NOT EXISTS idx_operations_shop_source 
ON operations(shop_source_id, last_modified_at);

CREATE INDEX IF NOT EXISTS idx_operations_shop_dest 
ON operations(shop_destination_id, last_modified_at);

-- Index composite pour les requêtes agents avec filtrage par shop et date
CREATE INDEX IF NOT EXISTS idx_operations_agent_filter 
ON operations(shop_source_id, shop_destination_id, last_modified_at);

-- ----------------------------------------------------------------------------
-- Index de recherche et détection de doublons
-- ----------------------------------------------------------------------------
-- Utilisé pour: recherche par code_ops (upload duplicate check)
CREATE INDEX IF NOT EXISTS idx_operations_code_ops 
ON operations(code_ops);

-- Utilisé par: WHERE montant_brut = ? AND agent_id = ? AND DATE(created_at) = ? AND type = ?
CREATE INDEX IF NOT EXISTS idx_operations_duplicate_check 
ON operations(montant_brut, agent_id, created_at, type);

-- ----------------------------------------------------------------------------
-- Index de tri et rapports
-- ----------------------------------------------------------------------------
-- Utilisé pour: recherche par date d'opération
CREATE INDEX IF NOT EXISTS idx_operations_date_op 
ON operations(date_op DESC);

-- Utilisé pour: statut et type (analyses et rapports)
CREATE INDEX IF NOT EXISTS idx_operations_statut 
ON operations(statut, type);

-- ============================================================================
-- TABLE: shops
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_shops_sync 
ON shops(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de recherche par clé naturelle
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_shops_designation 
ON shops(designation);

-- ============================================================================
-- TABLE: agents
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_agents_sync 
ON agents(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de recherche et authentification
-- ----------------------------------------------------------------------------
-- Recherche par username (clé naturelle)
CREATE INDEX IF NOT EXISTS idx_agents_username 
ON agents(username);

-- Index composite pour authentification
CREATE INDEX IF NOT EXISTS idx_agents_auth 
ON agents(username, password, is_active);

-- ----------------------------------------------------------------------------
-- Index de filtrage
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_agents_shop 
ON agents(shop_id, is_active);

-- ============================================================================
-- TABLE: clients
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_clients_sync 
ON clients(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de recherche par clés naturelles
-- ----------------------------------------------------------------------------
-- Recherche par nom (clé naturelle pour résolution ID)
CREATE INDEX IF NOT EXISTS idx_clients_nom 
ON clients(nom);

-- Recherche par téléphone (clé naturelle unique)
CREATE INDEX IF NOT EXISTS idx_clients_telephone 
ON clients(telephone);

-- ----------------------------------------------------------------------------
-- Index de filtrage
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_clients_shop 
ON clients(shop_id);

CREATE INDEX IF NOT EXISTS idx_clients_agent 
ON clients(agent_id);

-- ============================================================================
-- TABLE: taux_change
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_taux_sync 
ON taux_change(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de recherche par clé naturelle
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_taux_devise 
ON taux_change(devise_source, devise_cible, type);

-- ----------------------------------------------------------------------------
-- Index de filtrage
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_taux_actif 
ON taux_change(est_actif, date_effet DESC);

-- ============================================================================
-- TABLE: commissions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_commissions_sync 
ON commissions(last_modified_at, is_synced);

-- ----------------------------------------------------------------------------
-- Index de recherche par clé naturelle
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_commissions_type 
ON commissions(type);

-- ----------------------------------------------------------------------------
-- Index de filtrage
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_commissions_active 
ON commissions(is_active, type);

-- ============================================================================
-- TABLE: journal_caisse
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Index de recherche par entités
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_journal_shop_date 
ON journal_caisse(shop_id, date_action DESC);

CREATE INDEX IF NOT EXISTS idx_journal_agent 
ON journal_caisse(agent_id, date_action DESC);

CREATE INDEX IF NOT EXISTS idx_journal_operation 
ON journal_caisse(operation_id);

-- ----------------------------------------------------------------------------
-- Index de rapports
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_journal_reports 
ON journal_caisse(shop_id, type, date_action DESC);

-- ============================================================================
-- ANALYSE ET VÉRIFICATION
-- ============================================================================

-- Afficher tous les index de la table operations
SHOW INDEX FROM operations;

-- Analyser les performances des tables principales
ANALYZE TABLE operations, shops, agents, clients, taux_change, commissions;

-- Vérifier la taille des index
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS 'Size (MB)',
    ROUND((INDEX_LENGTH / 1024 / 1024), 2) AS 'Index Size (MB)',
    TABLE_ROWS AS 'Rows'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'inves2504808_6oor7p'
AND TABLE_NAME IN ('operations', 'shops', 'agents', 'clients', 'taux_change', 'commissions')
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- ============================================================================
-- REQUÊTES DE TEST POUR VÉRIFIER LES PERFORMANCES
-- ============================================================================

-- Test 1: Synchronisation operations (doit utiliser idx_operations_sync)
EXPLAIN SELECT * FROM operations 
WHERE last_modified_at > '2024-01-01 00:00:00' 
ORDER BY last_modified_at DESC 
LIMIT 1000;

-- Test 2: Filtrage operations par shop agent (doit utiliser idx_operations_agent_filter)
EXPLAIN SELECT * FROM operations 
WHERE (shop_source_id = 1 OR shop_destination_id = 1)
AND last_modified_at > '2024-01-01 00:00:00'
ORDER BY last_modified_at DESC;

-- Test 3: Recherche agent par username (doit utiliser idx_agents_username)
EXPLAIN SELECT id FROM agents 
WHERE username = 'agent_test' 
LIMIT 1;

-- Test 4: Recherche client par nom (doit utiliser idx_clients_nom)
EXPLAIN SELECT id FROM clients 
WHERE nom = 'Client Test' 
LIMIT 1;

-- Test 5: Détection doublons operations (doit utiliser idx_operations_duplicate_check)
EXPLAIN SELECT id FROM operations 
WHERE montant_brut = 100.00 
AND agent_id = 1 
AND DATE(created_at) = '2024-01-01'
AND type = 'depot'
LIMIT 1;

-- ============================================================================
-- MAINTENANCE RECOMMANDÉE
-- ============================================================================

-- À exécuter régulièrement (hebdomadaire) pour maintenir les performances:
-- OPTIMIZE TABLE operations, shops, agents, clients, taux_change, commissions;

-- À exécuter après modifications importantes de la structure:
-- ANALYZE TABLE operations, shops, agents, clients, taux_change, commissions;

-- ============================================================================
-- NOTES IMPORTANTES
-- ============================================================================

/*
1. Index Composites: 
   - L'ordre des colonnes dans un index composite est IMPORTANT
   - Les colonnes utilisées dans WHERE doivent être en premier
   - Les colonnes utilisées dans ORDER BY doivent être à la fin

2. Index sur clés étrangères:
   - Toutes les clés étrangères (shop_id, agent_id, client_id) doivent avoir des index
   - Améliore les performances des JOIN et des requêtes de filtrage

3. Index de synchronisation:
   - (last_modified_at, is_synced) est crucial pour les queries de sync
   - Permet de filtrer efficacement les données modifiées récemment

4. Monitoring:
   - Utilisez EXPLAIN pour analyser les requêtes
   - Vérifiez que MySQL utilise bien les index créés
   - Surveillez la taille des index (ne doit pas dépasser 30% de la taille des données)

5. Performance:
   - Ces index devraient réduire le temps de réponse des queries de 50-90%
   - Le temps d'insertion augmentera légèrement (5-10%) à cause des mises à jour d'index
   - Le gain en performance de lecture compense largement ce coût

6. Maintenance:
   - Exécutez OPTIMIZE TABLE mensuellement pour défragmenter
   - Exécutez ANALYZE TABLE après import/export massif de données
*/

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================

SELECT '✅ Index de synchronisation créés avec succès!' AS Status;
SELECT 'Exécutez SHOW INDEX FROM operations; pour vérifier les index' AS NextStep;
