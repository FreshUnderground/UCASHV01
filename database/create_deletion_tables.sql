-- ============================================================================
-- UCASH V01 - Tables pour Système de Suppression d'Opérations
-- Date: 2025-11-28
-- Description: Système de suppression avec validation en 2 étapes et corbeille
-- ============================================================================

USE ucash_db;

-- ============================================================================
-- TABLE: deletion_requests
-- Description: Demandes de suppression créées par l'admin
-- ============================================================================

CREATE TABLE IF NOT EXISTS `deletion_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code_ops` varchar(50) NOT NULL COMMENT 'Code unique de l\'opération à supprimer',
  `operation_id` int(11) DEFAULT NULL COMMENT 'ID local de l\'opération (peut changer)',
  
  -- Type et détails de l'opération
  `operation_type` varchar(50) NOT NULL,
  `montant` decimal(15,2) NOT NULL,
  `devise` varchar(10) DEFAULT 'USD',
  `destinataire` varchar(100) DEFAULT NULL,
  `expediteur` varchar(100) DEFAULT NULL,
  `client_nom` varchar(100) DEFAULT NULL,
  
  -- Informations de suppression
  `requested_by_admin_id` int(11) NOT NULL COMMENT 'ID de l\'admin qui demande',
  `requested_by_admin_name` varchar(100) NOT NULL,
  `request_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` text DEFAULT NULL COMMENT 'Raison de la suppression',
  
  -- Validation par l'agent
  `validated_by_agent_id` int(11) DEFAULT NULL,
  `validated_by_agent_name` varchar(100) DEFAULT NULL,
  `validation_date` timestamp NULL DEFAULT NULL,
  
  -- Validation par un admin (inter-admin)
  `validated_by_admin_id` int(11) DEFAULT NULL,
  `validated_by_admin_name` varchar(100) DEFAULT NULL,
  `validation_admin_date` timestamp NULL DEFAULT NULL,
  
  -- Statut de la demande
  `statut` enum('en_attente','admin_validee','agent_validee','refusee','annulee') DEFAULT 'en_attente',
  
  -- Métadonnées
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_modified_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` varchar(100) DEFAULT NULL,
  
  -- Synchronisation
  `is_synced` tinyint(1) DEFAULT 0,
  `synced_at` timestamp NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_code_ops` (`code_ops`),
  KEY `idx_statut` (`statut`),
  KEY `idx_operation_type` (`operation_type`),
  KEY `idx_admin` (`requested_by_admin_id`),
  KEY `idx_agent` (`validated_by_agent_id`),
  KEY `idx_sync` (`is_synced`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLE: operations_corbeille (Trash Bin)
-- Description: Stockage des opérations supprimées avec possibilité de restauration
-- ============================================================================

CREATE TABLE IF NOT EXISTS `operations_corbeille` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `original_operation_id` int(11) DEFAULT NULL COMMENT 'ID original avant suppression',
  
  -- Copie complète de l'opération supprimée
  `code_ops` varchar(50) NOT NULL,
  `type` varchar(50) NOT NULL,
  `shop_source_id` int(11) DEFAULT NULL,
  `shop_source_designation` varchar(100) DEFAULT NULL,
  `shop_destination_id` int(11) DEFAULT NULL,
  `shop_destination_designation` varchar(100) DEFAULT NULL,
  `agent_id` int(11) NOT NULL,
  `agent_username` varchar(100) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL,
  `client_nom` varchar(100) DEFAULT NULL,
  
  -- Montants
  `montant_brut` decimal(15,2) NOT NULL,
  `commission` decimal(15,2) DEFAULT 0.00,
  `montant_net` decimal(15,2) NOT NULL,
  `devise` varchar(10) DEFAULT 'USD',
  
  -- Détails
  `mode_paiement` varchar(50) DEFAULT 'cash',
  `destinataire` varchar(100) DEFAULT NULL,
  `telephone_destinataire` varchar(20) DEFAULT NULL,
  `reference` varchar(50) DEFAULT NULL,
  `sim_numero` varchar(20) DEFAULT NULL,
  `statut` varchar(50) DEFAULT 'terminee',
  `notes` text DEFAULT NULL,
  `observation` text DEFAULT NULL,
  
  -- Dates de l'opération originale
  `date_op` timestamp NOT NULL,
  `date_validation` timestamp NULL DEFAULT NULL,
  `created_at_original` timestamp NULL DEFAULT NULL,
  `last_modified_at_original` timestamp NULL DEFAULT NULL,
  `last_modified_by_original` varchar(100) DEFAULT NULL,
  
  -- Informations de suppression
  `deleted_by_admin_id` int(11) DEFAULT NULL,
  `deleted_by_admin_name` varchar(100) DEFAULT NULL,
  `validated_by_agent_id` int(11) DEFAULT NULL,
  `validated_by_agent_name` varchar(100) DEFAULT NULL,
  `deletion_request_id` int(11) DEFAULT NULL COMMENT 'Lien vers deletion_requests',
  `deletion_reason` text DEFAULT NULL,
  `deleted_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- Restauration
  `is_restored` tinyint(1) DEFAULT 0,
  `restored_at` timestamp NULL DEFAULT NULL,
  `restored_by` varchar(100) DEFAULT NULL,
  `restored_operation_id` int(11) DEFAULT NULL COMMENT 'Nouvel ID si restauré',
  
  -- Synchronisation
  `is_synced` tinyint(1) DEFAULT 0,
  `synced_at` timestamp NULL DEFAULT NULL,
  
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_code_ops_deleted` (`code_ops`, `deleted_at`),
  KEY `idx_code_ops` (`code_ops`),
  KEY `idx_type` (`type`),
  KEY `idx_shop_source` (`shop_source_id`),
  KEY `idx_shop_dest` (`shop_destination_id`),
  KEY `idx_agent` (`agent_id`),
  KEY `idx_deleted_by` (`deleted_by_admin_id`),
  KEY `idx_validated_by` (`validated_by_agent_id`),
  KEY `idx_restored` (`is_restored`),
  KEY `idx_sync` (`is_synced`),
  KEY `idx_deletion_request` (`deletion_request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- INDEX OPTIMIZATION
-- ============================================================================

-- Index pour recherches rapides sur code_ops
CREATE INDEX idx_deletion_code_ops ON deletion_requests(code_ops);
CREATE INDEX idx_corbeille_code_ops ON operations_corbeille(code_ops);

-- Index pour filtrer les demandes en attente
CREATE INDEX idx_deletion_pending ON deletion_requests(statut, request_date);

-- Index pour les validations admin
CREATE INDEX idx_deletion_admin_validated ON deletion_requests(validated_by_admin_id, validation_admin_date);

-- Index pour les validations agent
CREATE INDEX idx_deletion_agent_validated ON deletion_requests(validated_by_agent_id, validation_date);

-- Index pour filtrer les éléments non restaurés de la corbeille
CREATE INDEX idx_corbeille_active ON operations_corbeille(is_restored, deleted_at);

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Aucune donnée initiale requise

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DESCRIBE deletion_requests;
DESCRIBE operations_corbeille;

SELECT 'Tables de suppression créées avec succès!' AS Status;
