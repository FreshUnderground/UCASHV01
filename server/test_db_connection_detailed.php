<?php
// Detailed database connection test
require_once 'config/database.php';

try {
    // Test a simple query
    $stmt = $pdo->query("SELECT 1 as test");
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Database connection successful!\n";
    } else {
        echo "❌ Database connection failed!\n";
    }
    
    // Test if we can access the shops table
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM shops");
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Shops table accessible: " . $result['count'] . " records\n";
    } else {
        echo "❌ Shops table not accessible\n";
    }
    
    // Test if we can access the agents table
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM agents");
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Agents table accessible: " . $result['count'] . " records\n";
    } else {
        echo "❌ Agents table not accessible\n";
    }
    
} catch (Exception $e) {
    echo "❌ Database connection error: " . $e->getMessage() . "\n";
}
?>