-- Test script for sync_metadata table
USE ucash_db;

-- Drop the table if it exists
DROP TABLE IF EXISTS sync_metadata_test;

-- Create the table
CREATE TABLE sync_metadata_test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    last_sync_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_count INT DEFAULT 0,
    last_sync_user VARCHAR(100) DEFAULT 'system',
    notes TEXT,
    
    UNIQUE KEY unique_table (table_name),
    INDEX idx_last_sync (last_sync_date)
);

-- Insert test data
INSERT IGNORE INTO sync_metadata_test (table_name, sync_count) VALUES
('shops', 0),
('agents', 0);

-- Update the entries to add notes
UPDATE sync_metadata_test SET notes = 'Table des shops UCASH' WHERE table_name = 'shops' AND notes IS NULL;
UPDATE sync_metadata_test SET notes = 'Table des agents UCASH' WHERE table_name = 'agents' AND notes IS NULL;

-- Select to verify
SELECT * FROM sync_metadata_test;

-- Clean up
DROP TABLE IF EXISTS sync_metadata_test;