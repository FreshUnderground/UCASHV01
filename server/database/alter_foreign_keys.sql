-- ============================================
-- Migration: Utiliser clés naturelles au lieu d'IDs
-- ============================================

-- 1. Ajouter la colonne shop_designation dans agents
ALTER TABLE agents 
ADD COLUMN shop_designation VARCHAR(255) AFTER shop_id,
ADD INDEX idx_shop_designation (shop_designation);

-- 2. Copier les données existantes (shop_id -> shop_designation)
UPDATE agents a
JOIN shops s ON a.shop_id = s.id
SET a.shop_designation = s.designation;

-- 3. Ajouter la colonne agent_username dans clients
ALTER TABLE clients 
ADD COLUMN agent_username VARCHAR(100) AFTER agent_id,
ADD INDEX idx_agent_username (agent_username);

-- 4. Copier les données existantes (agent_id -> agent_username)
UPDATE clients c
JOIN agents a ON c.agent_id = a.id
SET c.agent_username = a.username
WHERE c.agent_id IS NOT NULL;

-- 5. Ajouter les colonnes dans operations
ALTER TABLE operations 
ADD COLUMN shop_source_designation VARCHAR(255) AFTER shop_source_id,
ADD COLUMN shop_destination_designation VARCHAR(255) AFTER shop_destination_id,
ADD COLUMN agent_username VARCHAR(100) AFTER agent_id,
ADD INDEX idx_shop_source_designation (shop_source_designation),
ADD INDEX idx_shop_destination_designation (shop_destination_designation),
ADD INDEX idx_agent_username_ops (agent_username);

-- 6. Copier les données existantes dans operations
UPDATE operations o
JOIN shops ss ON o.shop_source_id = ss.id
SET o.shop_source_designation = ss.designation;

UPDATE operations o
JOIN shops sd ON o.shop_destination_id = sd.id
SET o.shop_destination_designation = sd.designation
WHERE o.shop_destination_id IS NOT NULL;

UPDATE operations o
JOIN agents a ON o.agent_id = a.id
SET o.agent_username = a.username;

-- 7. Ajouter shop_designation dans clients aussi
ALTER TABLE clients 
ADD COLUMN shop_designation VARCHAR(255) AFTER shop_id,
ADD INDEX idx_shop_designation_clients (shop_designation);

UPDATE clients c
JOIN shops s ON c.shop_id = s.id
SET c.shop_designation = s.designation;

-- NOTE: On garde les colonnes *_id pour compatibilité descendante
-- Elles seront progressivement supprimées après migration complète

-- ============================================
-- Vérification des données
-- ============================================
SELECT 'agents' as table_name, COUNT(*) as total, 
       COUNT(shop_designation) as with_designation 
FROM agents
UNION ALL
SELECT 'clients', COUNT(*), COUNT(shop_designation) 
FROM clients
UNION ALL
SELECT 'operations', COUNT(*), COUNT(shop_source_designation) 
FROM operations;
