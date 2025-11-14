<?php
// Check if the database exists
require_once 'config/database.php';

try {
    // List all databases
    $stmt = $pdo->query("SHOW DATABASES");
    $databases = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "Available databases:\n";
    foreach ($databases as $db) {
        echo "- $db\n";
    }
    
    // Check if ucash_db exists
    if (in_array('ucash_db', $databases)) {
        echo "\n✅ Database 'ucash_db' exists\n";
    } else {
        echo "\n❌ Database 'ucash_db' does not exist\n";
    }
    
    // Check if ucash exists
    if (in_array('ucash', $databases)) {
        echo "✅ Database 'ucash' exists\n";
    } else {
        echo "❌ Database 'ucash' does not exist\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>