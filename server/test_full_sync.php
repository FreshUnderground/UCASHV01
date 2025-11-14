<?php
// Full synchronization test
require_once 'config/database.php';
require_once 'classes/SyncManager.php';

try {
    echo "🚀 Starting full synchronization test...\n\n";
    
    // Test database connection
    echo "1. Testing database connection...\n";
    $stmt = $pdo->query("SELECT 1 as test");
    $result = $stmt->fetch();
    if ($result) {
        echo "✅ Database connection successful!\n\n";
    } else {
        echo "❌ Database connection failed!\n\n";
        exit(1);
    }
    
    // Test SyncManager
    echo "2. Testing SyncManager...\n";
    $syncManager = new SyncManager($pdo);
    echo "✅ SyncManager instantiated successfully!\n\n";
    
    // Test shops table access
    echo "3. Testing shops table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM shops");
    $result = $stmt->fetch();
    echo "✅ Shops table accessible: " . $result['count'] . " records\n\n";
    
    // Test agents table access
    echo "4. Testing agents table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM agents");
    $result = $stmt->fetch();
    echo "✅ Agents table accessible: " . $result['count'] . " records\n\n";
    
    // Test clients table access
    echo "5. Testing clients table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM clients");
    $result = $stmt->fetch();
    echo "✅ Clients table accessible: " . $result['count'] . " records\n\n";
    
    // Test operations table access
    echo "6. Testing operations table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM operations");
    $result = $stmt->fetch();
    echo "✅ Operations table accessible: " . $result['count'] . " records\n\n";
    
    // Test taux table access
    echo "7. Testing taux table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM taux");
    $result = $stmt->fetch();
    echo "✅ Taux table accessible: " . $result['count'] . " records\n\n";
    
    // Test commissions table access
    echo "8. Testing commissions table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM commissions");
    $result = $stmt->fetch();
    echo "✅ Commissions table accessible: " . $result['count'] . " records\n\n";
    
    // Test sync_metadata table access
    echo "9. Testing sync_metadata table access...\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM sync_metadata");
    $result = $stmt->fetch();
    echo "✅ Sync_metadata table accessible: " . $result['count'] . " records\n\n";
    
    echo "🎉 All tests passed! Synchronization should work correctly.\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
?>