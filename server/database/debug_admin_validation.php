<?php
/**
 * Debug Admin Validation - Check what happens during admin validation
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Debugging admin validation process...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Check current state of deletion_requests
    echo "📋 Current deletion_requests:\n";
    $stmt = $db->query("SELECT * FROM deletion_requests ORDER BY id DESC LIMIT 5");
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($requests as $request) {
        echo "   ID: {$request['id']}\n";
        echo "   Code: {$request['code_ops']}\n";
        echo "   Status: {$request['statut']}\n";
        echo "   Requested by: {$request['requested_by_admin_name']}\n";
        echo "   Validated by admin: " . ($request['validated_by_admin_name'] ?? 'NULL') . "\n";
        echo "   Validated by agent: " . ($request['validated_by_agent_name'] ?? 'NULL') . "\n";
        echo "   Created: {$request['created_at']}\n";
        echo "   Last modified: {$request['last_modified_at']}\n";
        echo "   Is synced: " . ($request['is_synced'] ? 'YES' : 'NO') . "\n";
        echo "   ---\n";
    }
    
    // Test admin validation simulation
    $testCodeOps = '251211225322019';
    echo "\n🧪 Testing admin validation for: $testCodeOps\n";
    
    // Check if request exists
    $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
    $stmt->execute([$testCodeOps]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existing) {
        echo "❌ Request not found for code: $testCodeOps\n";
        exit(1);
    }
    
    echo "✅ Found request:\n";
    echo "   Current status: {$existing['statut']}\n";
    echo "   Admin validator: " . ($existing['validated_by_admin_name'] ?? 'NULL') . "\n";
    
    // Simulate admin validation update
    echo "\n🔄 Simulating admin validation update...\n";
    
    $updateStmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_admin_id = ?,
            validated_by_admin_name = ?,
            validation_admin_date = ?,
            statut = ?,
            last_modified_at = ?,
            last_modified_by = ?
        WHERE code_ops = ?
    ");
    
    $now = date('Y-m-d H:i:s');
    $testAdminId = 999;
    $testAdminName = 'test_admin';
    
    $result = $updateStmt->execute([
        $testAdminId,
        $testAdminName,
        $now,
        'admin_validee',
        $now,
        "admin_$testAdminName",
        $testCodeOps
    ]);
    
    if ($result && $updateStmt->rowCount() > 0) {
        echo "✅ Update successful! Rows affected: " . $updateStmt->rowCount() . "\n";
        
        // Check updated state
        $stmt->execute([$testCodeOps]);
        $updated = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "📋 Updated state:\n";
        echo "   Status: {$updated['statut']}\n";
        echo "   Admin validator: {$updated['validated_by_admin_name']}\n";
        echo "   Validation date: {$updated['validation_admin_date']}\n";
        echo "   Last modified: {$updated['last_modified_at']}\n";
        
        // Check if this should now appear for agent validation
        echo "\n🔍 Checking agent pending requests...\n";
        $agentStmt = $db->query("SELECT code_ops, statut FROM deletion_requests WHERE statut = 'admin_validee'");
        $agentRequests = $agentStmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "📋 Requests pending agent validation: " . count($agentRequests) . "\n";
        foreach ($agentRequests as $agentReq) {
            echo "   - {$agentReq['code_ops']}: {$agentReq['statut']}\n";
        }
        
    } else {
        echo "❌ Update failed! No rows affected.\n";
        echo "Error info: " . print_r($updateStmt->errorInfo(), true) . "\n";
    }
    
    // Check operations table to see if operation still exists
    echo "\n🔍 Checking if operation still exists in operations table...\n";
    $opStmt = $db->prepare("SELECT id, code_ops, type, montant_net, devise FROM operations WHERE code_ops = ?");
    $opStmt->execute([$testCodeOps]);
    $operation = $opStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($operation) {
        echo "✅ Operation still exists in operations table:\n";
        echo "   ID: {$operation['id']}\n";
        echo "   Code: {$operation['code_ops']}\n";
        echo "   Type: {$operation['type']}\n";
        echo "   Amount: {$operation['montant_net']} {$operation['devise']}\n";
        echo "   ➡️ This is CORRECT - operation should only be deleted after AGENT validation\n";
    } else {
        echo "❌ Operation NOT found in operations table\n";
        echo "   ➡️ This would be WRONG - operation should still exist until agent validates\n";
    }
    
    // Check operations_corbeille table
    echo "\n🗑️ Checking operations_corbeille table...\n";
    try {
        $corbeilleStmt = $db->prepare("SELECT * FROM operations_corbeille WHERE code_ops = ?");
        $corbeilleStmt->execute([$testCodeOps]);
        $corbeilleItem = $corbeilleStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($corbeilleItem) {
            echo "⚠️ Operation found in corbeille:\n";
            echo "   Code: {$corbeilleItem['code_ops']}\n";
            echo "   Deleted at: {$corbeilleItem['deleted_at']}\n";
            echo "   ➡️ This would be WRONG - should only be in corbeille after agent validation\n";
        } else {
            echo "✅ Operation NOT in corbeille yet\n";
            echo "   ➡️ This is CORRECT - should only go to corbeille after agent validation\n";
        }
    } catch (PDOException $e) {
        echo "⚠️ operations_corbeille table might not exist: " . $e->getMessage() . "\n";
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 DIAGNOSIS:\n";
    echo "   1. Admin validation should update status to 'admin_validee'\n";
    echo "   2. Operation should REMAIN in operations table\n";
    echo "   3. Operation should NOT be in corbeille yet\n";
    echo "   4. Agent should then see request for final validation\n";
    echo "   5. Only AGENT validation deletes operation and moves to corbeille\n";
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
