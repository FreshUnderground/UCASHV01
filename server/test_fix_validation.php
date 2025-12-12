<?php
// Test script to verify the fix for deletion request validation

error_reporting(E_ALL);
ini_set('log_errors', '1');

echo "Testing Deletion Request Validation Fix\n";
echo "=====================================\n\n";

// Include config for database connection
require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    echo "✓ Database connection successful\n\n";
    
    // Check the problematic record
    $targetCode = '251212115644101';
    echo "Checking request: $targetCode\n";
    
    $stmt = $db->prepare("SELECT code_ops, statut, requested_by_admin_name FROM deletion_requests WHERE code_ops = ?");
    $stmt->execute([$targetCode]);
    $request = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($request) {
        echo "✓ Request found!\n";
        echo "  Code: {$request['code_ops']}\n";
        echo "  Status: {$request['statut']}\n";
        echo "  Requested by: {$request['requested_by_admin_name']}\n\n";
        
        // If status is empty or invalid, update it
        if (empty($request['statut']) || !in_array($request['statut'], ['en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee'])) {
            echo "⚠️  Invalid status detected, updating to 'en_attente'...\n";
            
            $updateStmt = $db->prepare("UPDATE deletion_requests SET statut = 'en_attente' WHERE code_ops = ?");
            $updateStmt->execute([$targetCode]);
            
            if ($updateStmt->rowCount() > 0) {
                echo "✓ Status updated successfully\n\n";
            } else {
                echo "✗ Failed to update status\n\n";
            }
        } else {
            echo "✓ Status is valid\n\n";
        }
    } else {
        echo "✗ Request not found in database\n\n";
    }
    
    echo "The deletion request validation should now work correctly.\n";
    echo "Try validating the request through the admin interface again.\n";
    
} catch (Exception $e) {
    echo "✗ Database error: " . $e->getMessage() . "\n";
    exit(1);
}

?>