<?php
// Detailed SyncManager test
require_once 'config/database.php';
require_once 'classes/SyncManager.php';

try {
    $syncManager = new SyncManager($pdo);
    echo "✅ SyncManager instantiated successfully!\n";
    
    // Test if we can call a method on the SyncManager
    $reflection = new ReflectionClass($syncManager);
    $methods = $reflection->getMethods(ReflectionMethod::IS_PUBLIC);
    
    echo "✅ SyncManager public methods:\n";
    foreach ($methods as $method) {
        echo "  - " . $method->getName() . "\n";
    }
    
} catch (Exception $e) {
    echo "❌ SyncManager error: " . $e->getMessage() . "\n";
}
?>