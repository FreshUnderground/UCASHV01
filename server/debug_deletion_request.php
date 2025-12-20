<?php
// Debug script to test deletion request validation

error_reporting(E_ALL);
ini_set('log_errors', '1');

echo "Deletion Request Debug Script\n";
echo "===========================\n\n";

// Include config for database connection
require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    echo "✓ Database connection successful\n\n";
    
    // Check if deletion_requests table exists
    $stmt = $db->query("SHOW TABLES LIKE 'deletion_requests'");
    $tableExists = $stmt->fetch();
    if ($tableExists) {
        echo "✓ deletion_requests table exists\n";
        
        // Count total requests
        $stmt = $db->query("SELECT COUNT(*) as count FROM deletion_requests");
        $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        echo "Total deletion requests: $count\n";
        
        // Show sample requests
        if ($count > 0) {
            echo "\nSample requests:\n";
            $stmt = $db->query("SELECT code_ops, statut, requested_by_admin_name FROM deletion_requests ORDER BY request_date DESC LIMIT 5");
            $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            foreach ($requests as $request) {
                echo "- Code: {$request['code_ops']}, Status: {$request['statut']}, Requested by: {$request['requested_by_admin_name']}\n";
            }
        } else {
            echo "No deletion requests found in database\n";
        }
        
        // Check for the specific request mentioned in logs
        $targetCode = '251212115644101';
        echo "\nChecking for specific request: $targetCode\n";
        $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
        $stmt->execute([$targetCode]);
        $request = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($request) {
            echo "✓ Request found!\n";
            foreach ($request as $key => $value) {
                echo "  $key: $value\n";
            }
        } else {
            echo "✗ Request not found in database\n";
        }
        
    } else {
        echo "✗ deletion_requests table does not exist\n";
        echo "You may need to run the database migration script:\n";
        echo "database/create_deletion_tables.sql\n";
    }
    
} catch (Exception $e) {
    echo "✗ Database error: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\nTo manually test admin validation, you can run:\n";
echo "curl -X POST \\\n";
echo "  https://mahanaimeservice.investee-group.com/server/api/sync/deletion_requests/admin_validate.php \\\n";
echo "  -H 'Content-Type: application/json' \\\n";
echo "  -d '{\n";
echo "    \"code_ops\": \"251212115644101\",\n";
echo "    \"validated_by_admin_id\": 1,\n";
echo "    \"validated_by_admin_name\": \"Test Admin\"\n";
echo "  }'\n";

?>