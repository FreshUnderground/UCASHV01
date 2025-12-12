<?php
// Check the specific deletion request that's causing issues

error_reporting(E_ALL);
ini_set('log_errors', '1');

echo "Checking Specific Deletion Request\n";
echo "===============================\n\n";

require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    echo "✓ Database connection successful\n\n";
    
    $targetCode = '251212115644101';
    echo "Checking request: $targetCode\n\n";
    
    // Get detailed information about the request
    $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
    $stmt->execute([$targetCode]);
    $request = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($request) {
        echo "✓ Request found!\n";
        echo "Full request data:\n";
        
        foreach ($request as $key => $value) {
            // Handle null values and special formatting
            $displayValue = ($value === null) ? 'NULL' : $value;
            if (is_numeric($value) && strlen($value) > 10) {
                // Format large numbers
                $displayValue = number_format($value);
            }
            echo "  $key: $displayValue\n";
        }
        
        echo "\nStatus analysis:\n";
        $status = $request['statut'];
        echo "  Current status: '$status'\n";
        echo "  Status length: " . strlen($status) . "\n";
        echo "  Status is empty: " . (empty($status) ? 'YES' : 'NO') . "\n";
        
        // Check if status is valid
        $validStatuses = ['en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee'];
        echo "  Status is valid enum: " . (in_array($status, $validStatuses) ? 'YES' : 'NO') . "\n";
        
        if (!in_array($status, $validStatuses)) {
            echo "  ❌ Invalid status detected!\n";
            echo "  Valid statuses are: " . implode(', ', $validStatuses) . "\n";
        }
        
        echo "\nTrying manual update to fix status...\n";
        // Try to fix the status if it's invalid
        if (empty($status) || !in_array($status, $validStatuses)) {
            $updateStmt = $db->prepare("UPDATE deletion_requests SET statut = 'en_attente' WHERE code_ops = ?");
            $result = $updateStmt->execute([$targetCode]);
            
            if ($result) {
                echo "✓ Status updated to 'en_attente'\n";
                
                // Verify the update
                $verifyStmt = $db->prepare("SELECT statut FROM deletion_requests WHERE code_ops = ?");
                $verifyStmt->execute([$targetCode]);
                $updatedStatus = $verifyStmt->fetchColumn();
                echo "Verified status: '$updatedStatus'\n";
            } else {
                echo "✗ Failed to update status\n";
            }
        } else {
            echo "✓ Status is already valid\n";
        }
        
    } else {
        echo "✗ Request not found in database\n";
        
        // Check if there are any requests at all
        $countStmt = $db->query("SELECT COUNT(*) FROM deletion_requests");
        $count = $countStmt->fetchColumn();
        echo "Total deletion requests in database: $count\n";
        
        if ($count > 0) {
            echo "Sample requests:\n";
            $sampleStmt = $db->query("SELECT code_ops, statut FROM deletion_requests ORDER BY request_date DESC LIMIT 5");
            $samples = $sampleStmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($samples as $sample) {
                echo "  - {$sample['code_ops']}: {$sample['statut']}\n";
            }
        }
    }
    
} catch (Exception $e) {
    echo "✗ Database error: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\nDone.\n";

?>