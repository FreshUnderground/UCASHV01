<?php
/**
 * Check if operations_corbeille table exists and create if missing
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Checking operations_corbeille table...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Check if operations_corbeille table exists
    $stmt = $db->query("SHOW TABLES LIKE 'operations_corbeille'");
    $exists = $stmt->fetch();
    
    if ($exists) {
        echo "✅ Table 'operations_corbeille' exists\n";
        
        // Show table structure
        $stmt = $db->query("DESCRIBE operations_corbeille");
        $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo "   Columns: " . count($columns) . "\n";
        
        // Show record count
        $stmt = $db->query("SELECT COUNT(*) as count FROM operations_corbeille");
        $count = $stmt->fetch(PDO::FETCH_ASSOC);
        echo "   Records: " . $count['count'] . "\n\n";
        
        // Show some sample data if exists
        if ($count['count'] > 0) {
            $stmt = $db->query("SELECT code_ops, type, montant_net, devise, deleted_at FROM operations_corbeille ORDER BY deleted_at DESC LIMIT 5");
            $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo "📋 Sample records:\n";
            foreach ($samples as $sample) {
                echo "   - {$sample['code_ops']}: {$sample['type']} {$sample['montant_net']} {$sample['devise']} (deleted: {$sample['deleted_at']})\n";
            }
        }
    } else {
        echo "❌ Table 'operations_corbeille' NOT found\n";
        echo "🔧 Creating table...\n\n";
        
        // Create the table
        $createSQL = "
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
        ";
        
        $db->exec($createSQL);
        echo "✅ Table 'operations_corbeille' created successfully\n";
        
        // Add indexes
        $indexes = [
            "CREATE INDEX IF NOT EXISTS idx_corbeille_code_ops ON operations_corbeille(code_ops)",
            "CREATE INDEX IF NOT EXISTS idx_corbeille_active ON operations_corbeille(is_restored, deleted_at)"
        ];
        
        foreach ($indexes as $indexSQL) {
            try {
                $db->exec($indexSQL);
                echo "✅ Index created\n";
            } catch (PDOException $e) {
                if (strpos($e->getMessage(), 'already exists') === false) {
                    echo "⚠️ Index error: " . $e->getMessage() . "\n";
                }
            }
        }
    }
    
    echo "\n🎉 operations_corbeille table is ready!\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
