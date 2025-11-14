<?php
// Initialize basic UCASH tables
header('Content-Type: text/plain; charset=utf-8');
header('Access-Control-Allow-Origin: *');

echo "🔧 Basic Database Initialization Script\n";
echo "====================================\n\n";

try {
    // Database connection with root privileges
    echo "🔌 Connecting to MySQL...\n";
    $pdo = new PDO("mysql:host=localhost;charset=utf8mb4", "root", "");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create database
    echo "💾 Creating database 'ucash_db'...\n";
    $pdo->exec("CREATE DATABASE IF NOT EXISTS ucash_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    echo "✅ Database 'ucash_db' created or already exists\n\n";
    
    // Use the database
    echo "📂 Using database 'ucash_db'...\n";
    $pdo->exec("USE ucash_db");
    
    // Create basic tables
    echo "📋 Creating basic tables...\n";
    
    // Shops table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS shops (
            id INT AUTO_INCREMENT PRIMARY KEY,
            designation VARCHAR(255) NOT NULL,
            localisation VARCHAR(255) NOT NULL,
            capital_initial DECIMAL(15,2) DEFAULT 0.00,
            capital_actuel DECIMAL(15,2) DEFAULT 0.00,
            capital_cash DECIMAL(15,2) DEFAULT 0.00,
            capital_airtel_money DECIMAL(15,2) DEFAULT 0.00,
            capital_mpesa DECIMAL(15,2) DEFAULT 0.00,
            capital_orange_money DECIMAL(15,2) DEFAULT 0.00,
            creances DECIMAL(15,2) DEFAULT 0.00,
            dettes DECIMAL(15,2) DEFAULT 0.00,
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            UNIQUE KEY unique_designation (designation)
        )
    ");
    echo "✅ Table 'shops' created\n";
    
    // Agents table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS agents (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL,
            password VARCHAR(255) NOT NULL,
            nom VARCHAR(255) DEFAULT '',
            shop_id INT NOT NULL,
            role ENUM('ADMIN', 'AGENT') DEFAULT 'AGENT',
            is_active BOOLEAN DEFAULT TRUE,
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_shop (shop_id),
            UNIQUE KEY unique_username (username)
        )
    ");
    echo "✅ Table 'agents' created\n";
    
    // Clients table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS clients (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nom VARCHAR(255) NOT NULL,
            telephone VARCHAR(20) NOT NULL,
            adresse TEXT,
            solde DECIMAL(15,2) DEFAULT 0.00,
            shop_id INT NOT NULL,
            agent_id INT DEFAULT NULL,
            role ENUM('CLIENT') DEFAULT 'CLIENT',
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
            FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE SET NULL,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_shop (shop_id),
            INDEX idx_agent (agent_id),
            UNIQUE KEY unique_telephone (telephone)
        )
    ");
    echo "✅ Table 'clients' created\n";
    
    // Operations table with the correct column names
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS operations (
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
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
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
    echo "✅ Table 'operations' created\n";
    
    // Taux table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS taux (
            id INT AUTO_INCREMENT PRIMARY KEY,
            devise_source VARCHAR(10) DEFAULT 'USD' NOT NULL,
            devise_cible VARCHAR(10) NOT NULL,
            taux DECIMAL(10,4) NOT NULL,
            type ENUM('ACHAT', 'VENTE', 'MOYEN', 'NATIONAL', 'INTERNATIONAL_ENTRANT', 'INTERNATIONAL_SORTANT') NOT NULL,
            date_effet TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            est_actif BOOLEAN DEFAULT TRUE,
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
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
    echo "✅ Table 'taux' created\n";
    
    // Commissions table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS commissions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type ENUM('SORTANT', 'ENTRANT') NOT NULL,
            taux DECIMAL(5,2) NOT NULL,
            description TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            last_modified_by VARCHAR(100) DEFAULT 'system',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_synced BOOLEAN DEFAULT FALSE,
            synced_at TIMESTAMP NULL,
            INDEX idx_last_modified (last_modified_at),
            INDEX idx_synced (is_synced, synced_at),
            INDEX idx_type (type),
            UNIQUE KEY unique_type (type)
        )
    ");
    echo "✅ Table 'commissions' created\n";
    
    // Sync metadata table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS sync_metadata (
            id INT AUTO_INCREMENT PRIMARY KEY,
            table_name VARCHAR(100) NOT NULL,
            last_sync_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sync_count INT DEFAULT 0,
            last_sync_user VARCHAR(100) DEFAULT 'system',
            notes TEXT,
            UNIQUE KEY unique_table (table_name)
        )
    ");
    echo "✅ Table 'sync_metadata' created\n";
    
    // Insert default sync metadata
    echo "\n📋 Inserting default sync metadata...\n";
    $tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
    foreach ($tables as $table) {
        try {
            $stmt = $pdo->prepare("
                INSERT IGNORE INTO sync_metadata (table_name, sync_count, notes) 
                VALUES (?, 0, 'Initial sync metadata')
            ");
            $stmt->execute([$table]);
            echo "✅ Metadata for '$table' inserted\n";
        } catch (Exception $e) {
            echo "⚠️ Warning for '$table': " . $e->getMessage() . "\n";
        }
    }
    
    echo "\n🎉 Basic database initialization completed successfully!\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
?>