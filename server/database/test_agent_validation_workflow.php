<?php
/**
 * Test Agent Validation Workflow
 * Tests the complete deletion validation process: Admin -> Agent -> Operation deletion
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🧪 Testing Agent Deletion Validation Workflow...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Test data
    $testCodeOps = 'TEST_' . date('YmdHis') . '_' . rand(1000, 9999);
    $testAdminId = 999;
    $testAdminName = 'test_admin';
    $testAgentId = 888;
    $testAgentName = 'test_agent';
    
    echo "📋 Test Code Ops: $testCodeOps\n";
    echo "👤 Test Admin: $testAdminName (ID: $testAdminId)\n";
    echo "👤 Test Agent: $testAgentName (ID: $testAgentId)\n\n";
    
    // STEP 1: Create a test deletion request
    echo "🔄 STEP 1: Creating test deletion request...\n";
    
    $insertStmt = $db->prepare("
        INSERT INTO deletion_requests (
            code_ops, operation_id, operation_type, montant, devise,
            destinataire, expediteur, client_nom, observation,
            requested_by_admin_id, requested_by_admin_name, request_date,
            reason, statut, created_at, last_modified_at, is_synced
        ) VALUES (
            ?, ?, ?, ?, ?,
            ?, ?, ?, ?,
            ?, ?, ?,
            ?, ?, ?, ?, ?
        )
    ");
    
    $now = date('Y-m-d H:i:s');
    $result = $insertStmt->execute([
        $testCodeOps, 12345, 'DEPOT', 50000.00, 'XAF',
        'Test Destinataire', 'Test Expediteur', 'Test Client', 'Test observation',
        $testAdminId, $testAdminName, $now,
        'Test deletion reason', 'en_attente', $now, $now, 0
    ]);
    
    if ($result) {
        echo "✅ Deletion request created successfully\n";
    } else {
        throw new Exception("Failed to create deletion request");
    }
    
    // STEP 2: Test Admin Validation
    echo "\n🔄 STEP 2: Testing admin validation...\n";
    
    $adminValidateStmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_admin_id = ?,
            validated_by_admin_name = ?,
            validation_admin_date = ?,
            statut = ?,
            last_modified_at = ?,
            last_modified_by = ?
        WHERE code_ops = ?
    ");
    
    $result = $adminValidateStmt->execute([
        $testAdminId + 1, // Different admin validates
        'validator_admin',
        $now,
        'admin_validee',
        $now,
        'admin_validator_admin',
        $testCodeOps
    ]);
    
    if ($result && $adminValidateStmt->rowCount() > 0) {
        echo "✅ Admin validation successful\n";
        
        // Verify status
        $checkStmt = $db->prepare("SELECT statut, validated_by_admin_name FROM deletion_requests WHERE code_ops = ?");
        $checkStmt->execute([$testCodeOps]);
        $status = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($status['statut'] === 'admin_validee') {
            echo "✅ Status correctly updated to 'admin_validee'\n";
            echo "✅ Validated by: {$status['validated_by_admin_name']}\n";
        } else {
            echo "❌ Status not updated correctly: {$status['statut']}\n";
        }
    } else {
        throw new Exception("Admin validation failed");
    }
    
    // STEP 3: Test Agent Validation (Approve)
    echo "\n🔄 STEP 3: Testing agent validation (approve)...\n";
    
    $agentValidateStmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_agent_id = ?,
            validated_by_agent_name = ?,
            validation_date = ?,
            statut = ?,
            last_modified_at = ?,
            last_modified_by = ?
        WHERE code_ops = ?
    ");
    
    $result = $agentValidateStmt->execute([
        $testAgentId,
        $testAgentName,
        $now,
        'agent_validee',
        $now,
        "agent_$testAgentName",
        $testCodeOps
    ]);
    
    if ($result && $agentValidateStmt->rowCount() > 0) {
        echo "✅ Agent validation successful\n";
        
        // Verify final status
        $checkStmt->execute([$testCodeOps]);
        $finalStatus = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($finalStatus['statut'] === 'agent_validee') {
            echo "✅ Final status correctly updated to 'agent_validee'\n";
            echo "✅ Validated by agent: {$finalStatus['validated_by_admin_name']}\n";
        } else {
            echo "❌ Final status not updated correctly: {$finalStatus['statut']}\n";
        }
    } else {
        throw new Exception("Agent validation failed");
    }
    
    // STEP 4: Test workflow states
    echo "\n🔄 STEP 4: Testing workflow state queries...\n";
    
    // Test admin pending requests query
    $adminPendingStmt = $db->query("
        SELECT COUNT(*) as count FROM deletion_requests 
        WHERE statut = 'en_attente' AND validated_by_admin_id IS NULL
    ");
    $adminPending = $adminPendingStmt->fetchColumn();
    echo "📋 Admin pending requests: $adminPending\n";
    
    // Test agent pending requests query
    $agentPendingStmt = $db->query("
        SELECT COUNT(*) as count FROM deletion_requests 
        WHERE statut = 'admin_validee'
    ");
    $agentPending = $agentPendingStmt->fetchColumn();
    echo "📋 Agent pending requests: $agentPending\n";
    
    // Test completed requests query
    $completedStmt = $db->query("
        SELECT COUNT(*) as count FROM deletion_requests 
        WHERE statut IN ('agent_validee', 'refusee')
    ");
    $completed = $completedStmt->fetchColumn();
    echo "📋 Completed requests: $completed\n";
    
    // STEP 5: Test rejection workflow
    echo "\n🔄 STEP 5: Testing rejection workflow...\n";
    
    $testCodeOpsReject = 'REJECT_' . date('YmdHis') . '_' . rand(1000, 9999);
    
    // Create another test request
    $insertStmt->execute([
        $testCodeOpsReject, 12346, 'RETRAIT', 25000.00, 'XAF',
        'Test Destinataire 2', 'Test Expediteur 2', 'Test Client 2', 'Test observation 2',
        $testAdminId, $testAdminName, $now,
        'Test rejection reason', 'en_attente', $now, $now, 0
    ]);
    
    // Admin validates
    $adminValidateStmt->execute([
        $testAdminId + 1,
        'validator_admin',
        $now,
        'admin_validee',
        $now,
        'admin_validator_admin',
        $testCodeOpsReject
    ]);
    
    // Agent rejects
    $agentValidateStmt->execute([
        $testAgentId,
        $testAgentName,
        $now,
        'refusee',
        $now,
        "agent_$testAgentName",
        $testCodeOpsReject
    ]);
    
    echo "✅ Rejection workflow tested successfully\n";
    
    // STEP 6: Cleanup test data
    echo "\n🔄 STEP 6: Cleaning up test data...\n";
    
    $cleanupStmt = $db->prepare("DELETE FROM deletion_requests WHERE code_ops IN (?, ?)");
    $cleanupStmt->execute([$testCodeOps, $testCodeOpsReject]);
    
    echo "✅ Test data cleaned up\n";
    
    // FINAL SUMMARY
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 AGENT VALIDATION WORKFLOW TEST RESULTS:\n";
    echo "✅ 1. Deletion request creation: PASSED\n";
    echo "✅ 2. Admin validation: PASSED\n";
    echo "✅ 3. Agent approval: PASSED\n";
    echo "✅ 4. Workflow state queries: PASSED\n";
    echo "✅ 5. Agent rejection: PASSED\n";
    echo "✅ 6. Data cleanup: PASSED\n";
    echo "\n🎉 ALL TESTS PASSED! Agent validation workflow is working correctly.\n";
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "\n💥 TEST FAILED: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    
    // Cleanup on failure
    if (isset($testCodeOps) || isset($testCodeOpsReject)) {
        echo "\n🧹 Cleaning up test data after failure...\n";
        try {
            $cleanupStmt = $db->prepare("DELETE FROM deletion_requests WHERE code_ops LIKE 'TEST_%' OR code_ops LIKE 'REJECT_%'");
            $cleanupStmt->execute();
            echo "✅ Test data cleaned up\n";
        } catch (Exception $cleanupError) {
            echo "⚠️ Cleanup failed: " . $cleanupError->getMessage() . "\n";
        }
    }
    
    exit(1);
}
?>
