-- Test script for triggers
USE ucash_db;

-- Create a simple test table
CREATE TABLE IF NOT EXISTS test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create a simple sync_metadata table for testing
CREATE TABLE IF NOT EXISTS test_sync_metadata (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    last_sync_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_count INT DEFAULT 0,
    UNIQUE KEY unique_table (table_name)
);

-- Insert test metadata
INSERT IGNORE INTO test_sync_metadata (table_name, sync_count) VALUES ('test_table', 0);

-- Drop trigger if exists
DROP TRIGGER IF EXISTS test_table_sync_update;

-- Create a simple trigger for testing
CREATE TRIGGER test_table_sync_update 
AFTER UPDATE ON test_table 
FOR EACH ROW 
UPDATE test_sync_metadata 
SET last_sync_date = NOW(), sync_count = sync_count + 1 
WHERE table_name = 'test_table';

-- Insert a test record
INSERT INTO test_table (name) VALUES ('Test Record');

-- Check initial sync count
SELECT 'Before update:' as message, sync_count FROM test_sync_metadata WHERE table_name = 'test_table';

-- Update the record
UPDATE test_table SET name = 'Updated Test Record' WHERE name = 'Test Record';

-- Check sync count after update
SELECT 'After update:' as message, sync_count FROM test_sync_metadata WHERE table_name = 'test_table';

-- Clean up
DROP TABLE IF EXISTS test_table;
DROP TABLE IF EXISTS test_sync_metadata;
DROP TRIGGER IF EXISTS test_table_sync_update;