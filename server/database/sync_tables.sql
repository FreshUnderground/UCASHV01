-- Procédures stockées pour la synchronisation
-- Note: Simplified approach for better PHP execution compatibility

-- Drop existing procedure first
DROP PROCEDURE IF EXISTS MarkEntitiesAsSynced;

-- Simple approach: Use direct SQL statements instead of complex stored procedures
-- This is more compatible with PHP execution and different MySQL versions

CREATE PROCEDURE IF NOT EXISTS MarkEntitiesAsSynced(
    IN p_table_name VARCHAR(100),
    IN p_ids TEXT,
    IN p_user_id VARCHAR(100),
    IN p_synced_at VARCHAR(50)  -- Add synced_at parameter
)
BEGIN
    DECLARE sql_stmt TEXT;
    -- Use the provided synced_at timestamp instead of NOW() to maintain timezone consistency
    SET sql_stmt = CONCAT('UPDATE ', p_table_name, ' SET is_synced = TRUE, synced_at = ''', p_synced_at, ''', last_modified_by = ''', p_user_id, ''' WHERE id IN (', p_ids, ')');
    SET @sql = sql_stmt;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END;