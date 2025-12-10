-- Migration: Add billetage column to operations table
-- Date: 2025-12-09
-- Description: Add billetage column to store currency denomination information for withdrawals

USE ucash_db;

-- Add the billetage column to the operations table
ALTER TABLE operations 
ADD COLUMN billetage TEXT NULL COMMENT 'JSON string representation of currency denominations for withdrawals';

-- Add an index for faster queries on billetage (if needed)
-- CREATE INDEX idx_operations_billetage ON operations(billetage(255));

-- Verify the column was added
DESCRIBE operations;

-- Show the new column info
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'operations' 
  AND COLUMN_NAME = 'billetage'
  AND TABLE_SCHEMA = 'ucash_db';

-- Example of how to insert an operation with billetage:
-- INSERT INTO operations (
--   type, code_ops, 
--   shop_source_id, shop_source_designation,
--   agent_id, agent_username,
--   montant_brut, montant_net, commission,
--   mode_paiement, statut, devise,
--   destinataire, billetage,
--   created_at, last_modified_at, last_modified_by
-- ) VALUES (
--   'retrait', 'RET20251209_1234',
--   1, 'Shop A',
--   1, 'admin',
--   1000.00, 1000.00, 0.00,
--   'cash', 'terminee', 'USD',
--   'John Doe', '{"denominations":{"100":5,"50":2,"20":0,"10":0,"5":0,"1":0,"0.25":0,"0.10":0,"0.05":0,"0.01":0}}',
--   NOW(), NOW(), 'admin'
-- );

-- Example of how to update an operation with billetage:
-- UPDATE operations 
-- SET billetage = '{"denominations":{"100":5,"50":2,"20":0,"10":0,"5":0,"1":0,"0.25":0,"0.10":0,"0.05":0,"0.01":0}}',
--     last_modified_at = NOW(),
--     last_modified_by = 'admin'
-- WHERE code_ops = 'RET20251209_1234';