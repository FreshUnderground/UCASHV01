<!DOCTYPE html>
<html>
<head>
    <title>Setup Virtual Transaction Deletion System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .error { color: red; }
        .info { color: blue; }
        .warning { color: orange; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>🚀 Configuration du système de suppression des transactions virtuelles</h1>
    
<?php
require_once __DIR__ . '/config/database.php';

try {
    echo "<h2>🔍 Vérification des tables...</h2>";
    
    // Vérifier si les tables existent
    $tables = [
        'virtual_transaction_deletion_requests' => 'Demandes de suppression des transactions virtuelles',
        'virtual_transactions_corbeille' => 'Corbeille des transactions virtuelles supprimées'
    ];
    
    $allTablesExist = true;
    
    foreach ($tables as $table => $description) {
        $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
        $exists = $stmt->fetch();
        
        if ($exists) {
            echo "<p class='success'>✅ Table '$table' existe déjà</p>";
            
            // Afficher le nombre d'enregistrements
            $countStmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
            $count = $countStmt->fetch()['count'];
            echo "<p class='info'>   📊 Nombre d'enregistrements: $count</p>";
        } else {
            echo "<p class='error'>❌ Table '$table' n'existe pas</p>";
            $allTablesExist = false;
        }
    }
    
    if (!$allTablesExist) {
        echo "<h2>🔧 Création des tables manquantes...</h2>";
        
        // Créer la table des demandes de suppression
        $createRequestsSQL = "
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
        
        $pdo->exec($createRequestsSQL);
        echo "<p class='success'>✅ Table 'virtual_transaction_deletion_requests' créée</p>";
        
        // Créer la table de la corbeille
        $createCorbeilleSQL = "
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
        
        $pdo->exec($createCorbeilleSQL);
        echo "<p class='success'>✅ Table 'virtual_transactions_corbeille' créée</p>";
    }
    
    echo "<h2>🎯 Configuration terminée!</h2>";
    echo "<p class='success'>Le système de suppression des transactions virtuelles est maintenant opérationnel.</p>";
    
    echo "<h2>📋 Prochaines étapes:</h2>";
    echo "<ol>";
    echo "<li><strong>Créer le service Flutter:</strong> VirtualTransactionDeletionService</li>";
    echo "<li><strong>Ajouter l'interface utilisateur:</strong> Boutons de suppression dans les transactions virtuelles</li>";
    echo "<li><strong>Tester le workflow:</strong> Admin → Agent → Suppression → Corbeille</li>";
    echo "</ol>";
    
    echo "<h2>🔗 APIs disponibles:</h2>";
    echo "<ul>";
    echo "<li><code>/server/api/sync/virtual_transaction_deletion_requests/download.php</code></li>";
    echo "<li><code>/server/api/sync/virtual_transaction_deletion_requests/upload.php</code></li>";
    echo "<li><code>/server/api/sync/virtual_transaction_deletion_requests/admin_validate.php</code></li>";
    echo "<li><code>/server/api/sync/virtual_transaction_deletion_requests/validate.php</code></li>";
    echo "<li><code>/server/api/sync/virtual_transactions_corbeille/download.php</code></li>";
    echo "<li><code>/server/api/sync/virtual_transactions_corbeille/restore.php</code></li>";
    echo "</ul>";
    
} catch (Exception $e) {
    echo "<p class='error'>❌ Erreur: " . $e->getMessage() . "</p>";
    echo "<p class='error'>Fichier: " . $e->getFile() . "</p>";
    echo "<p class='error'>Ligne: " . $e->getLine() . "</p>";
}
?>

</body>
</html>
