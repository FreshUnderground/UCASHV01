-- Test script for indexes
USE ucash_db;

-- Show indexes for shops table
SELECT 'shops' as table_name, INDEX_NAME, COLUMN_NAME 
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = 'ucash_db' AND TABLE_NAME = 'shops' AND INDEX_NAME = 'idx_shops_sync_composite'
ORDER BY SEQ_IN_INDEX;

-- Show indexes for agents table
SELECT 'agents' as table_name, INDEX_NAME, COLUMN_NAME 
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = 'ucash_db' AND TABLE_NAME = 'agents' AND INDEX_NAME = 'idx_agents_sync_composite'
ORDER BY SEQ_IN_INDEX;

-- Show indexes for clients table
SELECT 'clients' as table_name, INDEX_NAME, COLUMN_NAME 
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = 'ucash_db' AND TABLE_NAME = 'clients' AND INDEX_NAME = 'idx_clients_sync_composite'
ORDER BY SEQ_IN_INDEX;

-- Show indexes for operations table
SELECT 'operations' as table_name, INDEX_NAME, COLUMN_NAME 
FROM INFORMATION_SCHEMA.STATISTICS 
WHERE TABLE_SCHEMA = 'ucash_db' AND TABLE_NAME = 'operations' AND INDEX_NAME = 'idx_operations_sync_composite'
ORDER BY SEQ_IN_INDEX;