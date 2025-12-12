<?php
// Test script to verify deletion endpoints are working correctly

echo "Testing Deletion Endpoints\n";
echo "========================\n\n";

// Test 1: Check if we can include the database config
echo "1. Testing database connection...\n";
try {
    require_once __DIR__ . '/config/database.php';
    echo "   ✓ Database config loaded successfully\n";
    
    // Test database connection
    $db = $pdo;
    echo "   ✓ Database connection established\n";
    
    // Test if deletion_requests table exists
    $stmt = $db->query("SHOW TABLES LIKE 'deletion_requests'");
    $tableExists = $stmt->fetch();
    if ($tableExists) {
        echo "   ✓ deletion_requests table exists\n";
    } else {
        echo "   ✗ deletion_requests table does not exist\n";
    }
    
} catch (Exception $e) {
    echo "   ✗ Database connection failed: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\n2. Testing endpoint files...\n";

// Test endpoint files
$endpoints = [
    'sync/deletion_requests/download.php',
    'sync/deletion_requests/upload.php',
    'sync/deletion_requests/validate.php',
    'sync/deletion_requests/admin_validate.php'
];

foreach ($endpoints as $endpoint) {
    $filePath = __DIR__ . '/api/' . $endpoint;
    if (file_exists($filePath)) {
        echo "   ✓ $endpoint exists\n";
        
        // Try to parse the PHP file for syntax errors
        $output = shell_exec("php -l " . escapeshellarg($filePath) . " 2>&1");
        if (strpos($output, 'No syntax errors detected') !== false) {
            echo "   ✓ $endpoint has no syntax errors\n";
        } else {
            echo "   ⚠ $endpoint may have syntax issues:\n      $output\n";
        }
    } else {
        echo "   ✗ $endpoint does not exist\n";
    }
}

echo "\n3. Summary\n";
echo "==========\n";
echo "Basic endpoint structure appears to be in place.\n";
echo "For full testing, you would need to:\n";
echo "  - Create a test deletion request\n";
echo "  - Test admin validation\n";
echo "  - Test agent validation\n";

?>