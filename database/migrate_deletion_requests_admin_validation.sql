-- ============================================================================
-- UCASH V01 - Migration: Admin Validation for Deletion Requests
-- Date: 2025-12-05
-- Description: Add admin validation columns and update status enum
-- ============================================================================

USE ucash_db;

-- Add admin validation columns to deletion_requests table
ALTER TABLE deletion_requests 
ADD COLUMN `validated_by_admin_id` int(11) DEFAULT NULL AFTER `validated_by_agent_name`,
ADD COLUMN `validated_by_admin_name` varchar(100) DEFAULT NULL AFTER `validated_by_admin_id`,
ADD COLUMN `validation_admin_date` timestamp NULL DEFAULT NULL AFTER `validated_by_admin_name`;

-- Update the status enum to include new statuses
ALTER TABLE deletion_requests 
MODIFY COLUMN `statut` enum('en_attente','admin_validee','agent_validee','refusee','annulee') DEFAULT 'en_attente';

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_deletion_admin_validated ON deletion_requests(validated_by_admin_id, validation_admin_date);
CREATE INDEX IF NOT EXISTS idx_deletion_agent_validated ON deletion_requests(validated_by_agent_id, validation_date);

-- Update existing records:
-- - Records with validated_by_agent_id should have status 'agent_validee'
-- - Records with statut = 'validee' should be converted to 'admin_validee' (assuming they were admin validated)
UPDATE deletion_requests 
SET statut = 'agent_validee' 
WHERE validated_by_agent_id IS NOT NULL AND statut = 'validee';

UPDATE deletion_requests 
SET statut = 'admin_validee' 
WHERE statut = 'validee';

-- Verification
DESCRIBE deletion_requests;
SELECT DISTINCT statut FROM deletion_requests;

SELECT 'Migration des demandes de suppression terminée avec succès!' AS Status;