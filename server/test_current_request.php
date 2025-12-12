<?php
// Test the exact scenario that's failing

echo "Testing Current Request Scenario\n";
echo "==============================\n\n";

// Simulate what we know from the logs:
// 1. The local validation works
// 2. The background sync fails with 400

echo "Step 1: Check if the request exists in database\n";

require_once __DIR__ . '/config/database.php';

try {
    $db = $pdo;
    
    $codeOps = '251212115644101';
    
    // Check current status
    $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
    $stmt->execute([$codeOps]);
    $request = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($request) {
        echo "✓ Request found\n";
        echo "Current status: " . $request['statut'] . "\n";
        echo "Validated by admin ID: " . ($request['validated_by_admin_id'] ?? 'NULL') . "\n";
        echo "Validated by admin name: " . ($request['validated_by_admin_name'] ?? 'NULL') . "\n\n";
        
        // Check if it's already validated
        if ($request['statut'] === 'admin_validee') {
            echo "ℹ️  Request is already admin validated\n";
            echo "This might explain why the background sync fails - it's trying to validate an already validated request.\n\n";
        }
        
        // Try to simulate what the Flutter app sends during background sync
        echo "Step 2: Simulating background sync request\n";
        
        // This is what the Flutter app should be sending
        $backgroundSyncData = [
            'code_ops' => $codeOps,
            'validated_by_admin_id' => $request['requested_by_admin_id'] ?? 1,
            'validated_by_admin_name' => $request['requested_by_admin_name'] ?? 'admin'
        ];
        
        echo "Background sync data: " . json_encode($backgroundSyncData) . "\n\n";
        
        // Test our parsing logic
        $parsedCodeOps = $backgroundSyncData['code_ops'] ?? $backgroundSyncData['codeOps'] ?? null;
        $parsedAdminId = $backgroundSyncData['validated_by_admin_id'] ?? $backgroundSyncData['validatedByAdminId'] ?? null;
        $parsedAdminName = $backgroundSyncData['validated_by_admin_name'] ?? $backgroundSyncData['validatedByAdminName'] ?? null;
        
        echo "Parsed data:\n";
        echo "  codeOps: " . ($parsedCodeOps ?? 'NULL') . "\n";
        echo "  adminId: " . ($parsedAdminId ?? 'NULL') . "\n";
        echo "  adminName: " . ($parsedAdminName ?? 'NULL') . "\n\n";
        
        $isValid = !empty($parsedCodeOps) && !empty($parsedAdminId) && !empty($parsedAdminName);
        echo "Request would be valid: " . ($isValid ? 'YES' : 'NO') . "\n\n";
        
        if ($isValid) {
            echo "✓ The data format looks correct\n";
            echo "If this still fails, the issue might be:\n";
            echo "1. The request is already validated\n";
            echo "2. Network/authentication issues\n";
            echo "3. Server-side validation is too strict\n\n";
        }
        
    } else {
        echo "✗ Request not found\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}

echo "Next steps:\n";
echo "1. Check server logs for detailed error messages\n";
echo "2. Verify the request isn't already validated\n";
echo "3. Test with the HTML page to confirm server works\n";

?>