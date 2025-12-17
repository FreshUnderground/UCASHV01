<?php
/**
 * Script pour vérifier et créer les tables de suppression des transactions virtuelles
 */

require_once __DIR__ . '/config/database.php';

try {
    echo "🔍 Vérification des tables de suppression des transactions virtuelles...\n\n";
    
    // Vérifier si les tables existent
    $tables = [
        'virtual_transaction_deletion_requests',
        'virtual_transactions_corbeille'
    ];
    
    foreach ($tables as $table) {
        $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
        $exists = $stmt->fetch();
        
        if ($exists) {
            echo "✅ Table '$table' existe déjà\n";
            
            // Afficher le nombre d'enregistrements
            $countStmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
            $count = $countStmt->fetch()['count'];
            echo "   📊 Nombre d'enregistrements: $count\n\n";
        } else {
            echo "❌ Table '$table' n'existe pas\n";
            echo "   🔧 Création de la table...\n";
            
            if ($table === 'virtual_transaction_deletion_requests') {
                $createSQL = "
                CREATE TABLE IF NOT EXISTS virtual_transaction_deletion_requests (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    reference VARCHAR(255) NOT NULL,
                    virtual_transaction_id INT,
                    transaction_type VARCHAR(100) NOT NULL,
                    montant DECIMAL(15,2) NOT NULL,
                    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
                    destinataire VARCHAR(255),
                    expediteur VARCHAR(255),
                    client_nom VARCHAR(255),
                    
                    requested_by_admin_id INT NOT NULL,
                    requested_by_admin_name VARCHAR(255) NOT NULL,
                    request_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    reason TEXT,
                    
                    validated_by_admin_id INT NULL,
                    validated_by_admin_name VARCHAR(255) NULL,
                    validation_admin_date DATETIME NULL,
                    
                    validated_by_agent_id INT NULL,
                    validated_by_agent_name VARCHAR(255) NULL,
                    validation_date DATETIME NULL,
                    
                    statut ENUM('en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee') NOT NULL DEFAULT 'en_attente',
                    last_modified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    last_modified_by VARCHAR(255),
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    
                    is_synced BOOLEAN NOT NULL DEFAULT FALSE,
                    synced_at DATETIME NULL,
                    
                    INDEX idx_reference (reference),
                    INDEX idx_virtual_transaction_id (virtual_transaction_id),
                    INDEX idx_statut (statut),
                    INDEX idx_requested_by_admin (requested_by_admin_id),
                    INDEX idx_validated_by_admin (validated_by_admin_id),
                    INDEX idx_validated_by_agent (validated_by_agent_id),
                    INDEX idx_last_modified (last_modified_at),
                    INDEX idx_is_synced (is_synced)
                )";
            } else {
                $createSQL = "
                CREATE TABLE IF NOT EXISTS virtual_transactions_corbeille (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    reference VARCHAR(255) NOT NULL,
                    virtual_transaction_id INT,
                    
                    montant_virtuel DECIMAL(15,2) NOT NULL,
                    frais DECIMAL(15,2) NOT NULL DEFAULT 0,
                    montant_cash DECIMAL(15,2) NOT NULL,
                    devise VARCHAR(10) NOT NULL DEFAULT 'USD',
                    sim_numero VARCHAR(50) NOT NULL,
                    shop_id INT NOT NULL,
                    shop_designation VARCHAR(255),
                    agent_id INT NOT NULL,
                    agent_username VARCHAR(255),
                    client_nom VARCHAR(255),
                    client_telephone VARCHAR(50),
                    statut VARCHAR(50) NOT NULL,
                    date_enregistrement DATETIME NOT NULL,
                    date_validation DATETIME,
                    notes TEXT,
                    is_administrative BOOLEAN NOT NULL DEFAULT FALSE,
                    
                    deleted_by_agent_id INT NOT NULL,
                    deleted_by_agent_name VARCHAR(255) NOT NULL,
                    deletion_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    deletion_reason TEXT,
                    
                    is_restored BOOLEAN NOT NULL DEFAULT FALSE,
                    restored_by VARCHAR(255) NULL,
                    restoration_date DATETIME NULL,
                    restoration_reason TEXT,
                    
                    is_synced BOOLEAN NOT NULL DEFAULT FALSE,
                    synced_at DATETIME NULL,
                    last_modified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    last_modified_by VARCHAR(255),
                    
                    INDEX idx_reference (reference),
                    INDEX idx_virtual_transaction_id (virtual_transaction_id),
                    INDEX idx_shop_id (shop_id),
                    INDEX idx_agent_id (agent_id),
                    INDEX idx_deleted_by_agent (deleted_by_agent_id),
                    INDEX idx_is_restored (is_restored),
                    INDEX idx_is_synced (is_synced),
                    INDEX idx_deletion_date (deletion_date),
                    INDEX idx_last_modified (last_modified_at)
                )";
            }
            
            $pdo->exec($createSQL);
            echo "   ✅ Table '$table' créée avec succès\n\n";
        }
    }
    
    echo "🎯 RÉSUMÉ:\n";
    echo "Les tables de suppression des transactions virtuelles sont maintenant disponibles.\n";
    echo "Vous pouvez maintenant utiliser le système de suppression des transactions virtuelles.\n\n";
    
    echo "📋 PROCHAINES ÉTAPES:\n";
    echo "1. Créer le VirtualTransactionDeletionService en Flutter\n";
    echo "2. Ajouter les boutons de suppression dans l'interface des transactions virtuelles\n";
    echo "3. Tester le workflow complet\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    echo "   Fichier: " . $e->getFile() . "\n";
    echo "   Ligne: " . $e->getLine() . "\n";
}
?>
