<?php
// Initialize UCASH database
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

try {
    // Database connection with root privileges
    $pdo = new PDO("mysql:host=localhost;charset=utf8mb4", "root", "");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create database
    $pdo->exec("CREATE DATABASE IF NOT EXISTS ucash_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    echo "✅ Database 'ucash_db' created or already exists\n";
    
    // Use the database
    $pdo->exec("USE ucash_db");
    
    // Read and execute the sync_tables.sql file
    $sql = file_get_contents(__DIR__ . '/database/sync_tables.sql');
    $pdo->exec($sql);
    
    echo "✅ Tables created successfully\n";
    
    // Insert default sync metadata
    $tables = ['shops', 'agents', 'clients', 'operations', 'taux', 'commissions'];
    foreach ($tables as $table) {
        $stmt = $pdo->prepare("
            INSERT IGNORE INTO sync_metadata (table_name, sync_count, notes) 
            VALUES (?, 0, 'Initial sync metadata')
        ");
        $stmt->execute([$table]);
    }
    
    echo "✅ Sync metadata initialized\n";
    
    $response = [
        'success' => true,
        'message' => 'Database initialized successfully'
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>