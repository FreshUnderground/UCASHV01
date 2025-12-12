-- Fix for deletion_requests statut field to ensure proper default value
-- This prevents empty string values that cause validation issues

USE ucash_db;

-- First, update any existing records with empty statut to 'en_attente'
UPDATE deletion_requests 
SET statut = 'en_attente' 
WHERE statut = '' OR statut IS NULL;

-- Then, modify the column to have a proper default and not allow empty values
ALTER TABLE deletion_requests 
MODIFY COLUMN statut ENUM('en_attente','admin_validee','agent_validee','refusee','annulee') 
NOT NULL DEFAULT 'en_attente';

-- Verify the fix
SELECT code_ops, statut FROM deletion_requests WHERE statut = '' OR statut IS NULL;