<?php
// Step-by-step database initialization
header('Content-Type: text/plain; charset=utf-8');

echo "🔧 Step-by-Step Database Initialization\n";
echo "====================================\n\n";

try {
    // Connect to MySQL
    echo "1. Connecting to MySQL...\n";
    $pdo = new PDO("mysql:host=localhost", "root", "");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Connected\n\n";
    
    // Create database
    echo "2. Creating database...\n";
    $pdo->exec("CREATE DATABASE IF NOT EXISTS ucash_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    echo "✅ Database created\n\n";
    
    // Use database
    echo "3. Using database...\n";
    $pdo->exec("USE ucash_db");
    echo "✅ Database selected\n\n";
    
    // Drop existing tables to ensure clean slate
    echo "4. Dropping existing tables...\n";
    $tables = ['sync_metadata', 'commissions', 'taux', 'operations', 'clients', 'agents', 'shops'];
    foreach ($tables as $table) {
        $pdo->exec("DROP TABLE IF EXISTS `$table`");
        echo "✅ Dropped table: $table\n";
    }
    echo "\n";
    
    // Create shops table with full structure
    echo "5. Creating shops table...\n";
    $pdo->exec("
        CREATE TABLE shops (
            id INT AUTO_INCREMENT PRIMARY KEY,
            designation VARCHAR(255) NOT NULL,
            localisation VARCHAR(255) NOT NULL,
            devise_principale VARCHAR(10) DEFAULT 'USD' NOT NULL,
            devise_secondaire VARCHAR(10) DEFAULT NULL,
            capital_actuel_devise1 DECIMAL(15,2) DEFAULT 0.00,
            capital_cash_devise1 DECIMAL(15,2) DEFAULT 0.00,
            capital_airtel_money_devise1 DECIMAL(15,2) DEFAULT 0.00,
            capital_mpesa_devise1 DECIMAL(15,2) DEFAULT 0.00,
            capital_orange_money_devise1 DECIMAL(15,2) DEFAULT 0.00,
            capital_actuel_devise2 DECIMAL(15,2) DEFAULT NULL,
            capital_cash_devise2 DECIMAL(15,2) DEFAULT NULL,
            capital_airtel_money_devise2 DECIMAL(15,2) DEFAULT NULL,
            capital_mpesa_devise2 DECIMAL(15,2) DEFAULT NULL,
            capital_orange_money_devise2 DECIMAL(15,2) DEFAULT NULL,
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Index
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_devise_principale (devise_principale),
            INDEX idx_devise_secondaire (devise_secondaire)
        )
    ");
    echo "✅ Shops table created\n\n";
    
    // Create agents table with full structure
    echo "6. Creating agents table...\n";
    $pdo->exec("
        CREATE TABLE agents (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL,
            password VARCHAR(255) NOT NULL,
            nom VARCHAR(255),
            telephone VARCHAR(20) DEFAULT '',
            adresse TEXT,
            role ENUM('AGENT', 'ADMIN') DEFAULT 'AGENT',
            shop_id INT NOT NULL,
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Contraintes et index
            FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_shop (shop_id),
            UNIQUE KEY unique_username (username)
        )
    ");
    echo "✅ Agents table created\n\n";
    
    // Create clients table with full structure
    echo "7. Creating clients table...\n";
    $pdo->exec("
        CREATE TABLE clients (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nom VARCHAR(255) NOT NULL,
            telephone VARCHAR(20) NOT NULL,
            adresse TEXT,
            solde DECIMAL(15,2) DEFAULT 0.00,
            shop_id INT NOT NULL,
            agent_id INT DEFAULT NULL,
            role ENUM('CLIENT') DEFAULT 'CLIENT',
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Contraintes et index
            FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
            FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_shop (shop_id),
            INDEX idx_agent (agent_id),
            UNIQUE KEY unique_telephone (telephone)
        )
    ");
    echo "✅ Clients table created\n\n";
    
    // Create operations table with full structure
    echo "8. Creating operations table...\n";
    $pdo->exec("
        CREATE TABLE operations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type ENUM('depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant') NOT NULL,
            montant_brut DECIMAL(15,2) NOT NULL,
            montant_net DECIMAL(15,2) NOT NULL,
            commission DECIMAL(15,2) DEFAULT 0.00,
            devise VARCHAR(10) DEFAULT 'USD' NOT NULL,
            client_id INT DEFAULT NULL,
            shop_source_id INT NOT NULL,
            shop_destination_id INT DEFAULT NULL,
            agent_id INT NOT NULL,
            mode_paiement ENUM('cash', 'airtelMoney', 'mPesa', 'orangeMoney') DEFAULT 'cash',
            statut ENUM('enAttente', 'validee', 'terminee', 'annulee') DEFAULT 'terminee',
            reference VARCHAR(100) DEFAULT NULL,
            notes TEXT,
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Contraintes et index
            FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
            FOREIGN KEY (shop_source_id) REFERENCES shops(id) ON DELETE CASCADE,
            FOREIGN KEY (shop_destination_id) REFERENCES shops(id) ON DELETE SET NULL,
            FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_client (client_id),
            INDEX idx_shop_source (shop_source_id),
            INDEX idx_shop_destination (shop_destination_id),
            INDEX idx_agent (agent_id),
            INDEX idx_reference (reference),
            INDEX idx_statut (statut),
            INDEX idx_type (type),
            INDEX idx_devise (devise)
        )
    ");
    echo "✅ Operations table created\n\n";
    
    // Create taux table
    echo "9. Creating taux table...\n";
    $pdo->exec("
        CREATE TABLE taux (
            id INT AUTO_INCREMENT PRIMARY KEY,
            devise_source VARCHAR(10) DEFAULT 'USD' NOT NULL,
            devise_cible VARCHAR(10) NOT NULL,
            taux DECIMAL(10,4) NOT NULL,
            type ENUM('ACHAT', 'VENTE', 'MOYEN', 'NATIONAL', 'INTERNATIONAL_ENTRANT', 'INTERNATIONAL_SORTANT') NOT NULL,
            date_effet TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            est_actif BOOLEAN DEFAULT TRUE,
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Index
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_devise_source (devise_source),
            INDEX idx_devise_cible (devise_cible),
            INDEX idx_type (type),
            INDEX idx_date_effet (date_effet),
            INDEX idx_est_actif (est_actif),
            UNIQUE KEY unique_devise_pair_type (devise_source, devise_cible, type)
        )
    ");
    echo "✅ Taux table created\n\n";
    
    // Create commissions table
    echo "10. Creating commissions table...\n";
    $pdo->exec("
        CREATE TABLE commissions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type ENUM('SORTANT', 'ENTRANT') NOT NULL,
            taux DECIMAL(5,2) NOT NULL,
            description TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            
            -- Champs de synchronisation
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            
            -- Index
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_type (type),
            UNIQUE KEY unique_type (type)
        )
    ");
    echo "✅ Commissions table created\n\n";
    
    // Create sync_metadata table
    echo "11. Creating sync_metadata table...\n";
    $pdo->exec("
        CREATE TABLE sync_metadata (
            id INT AUTO_INCREMENT PRIMARY KEY,
            table_name VARCHAR(100) NOT NULL,
            last_sync_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sync_count INT DEFAULT 0,
            last_sync_user VARCHAR(100) DEFAULT 'system',
            notes TEXT,
            
            UNIQUE KEY unique_table (table_name),
            INDEX idx_last_sync (last_sync_date)
        )
    ");
    echo "✅ Sync metadata table created\n\n";
    
    // Insert default metadata
    echo "12. Inserting default metadata...\n";
    $tables = [
        'shops' => 'Table des shops UCASH',
        'agents' => 'Table des agents UCASH',
        'clients' => 'Table des clients UCASH',
        'operations' => 'Table des opérations UCASH',
        'taux' => 'Table des taux de change',
        'commissions' => 'Table des commissions'
    ];
    
    foreach ($tables as $table => $description) {
        $stmt = $pdo->prepare("
            INSERT IGNORE INTO sync_metadata (table_name, sync_count, notes) 
            VALUES (?, 0, ?)
        ");
        $stmt->execute([$table, $description]);
    }
    echo "✅ Default metadata inserted\n\n";
    
    // Verify tables
    echo "13. Verifying tables...\n";
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    foreach ($tables as $table) {
        echo "- $table\n";
    }
    echo "✅ All tables verified\n\n";
    
    echo "🎉 Database initialization completed successfully!\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
?>