-- Test script for database structure
USE ucash_db;

-- Check if all tables exist
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'ucash_db' 
AND TABLE_NAME IN ('shops', 'agents', 'clients', 'operations', 'taux', 'commissions', 'sync_metadata')
ORDER BY TABLE_NAME;

-- Check if views exist
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'ucash_db' 
AND TABLE_NAME IN ('v_sync_status', 'v_unsync_entities')
ORDER BY TABLE_NAME;

-- Check if triggers exist
SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE
FROM INFORMATION_SCHEMA.TRIGGERS 
WHERE TRIGGER_SCHEMA = 'ucash_db'
AND TRIGGER_NAME IN ('shops_sync_update', 'agents_sync_update', 'clients_sync_update', 'operations_sync_update', 'taux_sync_update', 'commissions_sync_update')
ORDER BY TRIGGER_NAME;

-- Check if the sync_metadata table has the correct structure
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ucash_db' AND TABLE_NAME = 'sync_metadata'
ORDER BY ORDINAL_POSITION;