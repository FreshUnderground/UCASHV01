<?php
/**
 * Debug HTTP 400 error in admin validation endpoint
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Debugging HTTP 400 error in admin validation...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Check current state of deletion_requests
    echo "📋 Current deletion_requests state:\n";
    $stmt = $db->query("SELECT * FROM deletion_requests ORDER BY id DESC LIMIT 3");
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($requests as $request) {
        echo "   ID: {$request['id']}\n";
        echo "   Code: {$request['code_ops']}\n";
        echo "   Status: {$request['statut']}\n";
        echo "   Admin validator: " . ($request['validated_by_admin_name'] ?? 'NULL') . "\n";
        echo "   Admin validation date: " . ($request['validation_admin_date'] ?? 'NULL') . "\n";
        echo "   Is synced: " . ($request['is_synced'] ? 'YES' : 'NO') . "\n";
        echo "   ---\n";
    }
    
    // Test the exact API call that's failing
    $testCodeOps = '251211225017939';
    echo "\n🧪 Testing admin validation API call for: $testCodeOps\n";
    
    // Check if request exists and its current state
    $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = ?");
    $stmt->execute([$testCodeOps]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existing) {
        echo "❌ Request not found for code: $testCodeOps\n";
        echo "Creating test request...\n";
        
        // Create a test request
        $insertStmt = $db->prepare("
            INSERT INTO deletion_requests (
                code_ops, operation_type, montant, devise, 
                requested_by_admin_id, requested_by_admin_name, 
                request_date, reason, statut
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $insertStmt->execute([
            $testCodeOps,
            'Transfert National',
            2900.00,
            'USD',
            1,
            'admin',
            date('Y-m-d H:i:s'),
            'Test validation',
            'en_attente'
        ]);
        
        echo "✅ Test request created\n";
        
        // Re-fetch the request
        $stmt->execute([$testCodeOps]);
        $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    echo "✅ Found request:\n";
    echo "   Current status: {$existing['statut']}\n";
    echo "   Admin validator: " . ($existing['validated_by_admin_name'] ?? 'NULL') . "\n";
    echo "   Is synced: " . ($existing['is_synced'] ? 'YES' : 'NO') . "\n";
    
    // Test different scenarios that might cause HTTP 400
    echo "\n🔍 Testing potential HTTP 400 causes:\n";
    
    // Scenario 1: Request already validated
    if ($existing['statut'] === 'admin_validee') {
        echo "⚠️ CAUSE 1: Request already validated (status = admin_validee)\n";
        echo "   This could cause HTTP 400 if trying to validate again\n";
    }
    
    // Scenario 2: Missing required fields
    $requiredFields = ['code_ops', 'statut'];
    foreach ($requiredFields as $field) {
        if (empty($existing[$field])) {
            echo "⚠️ CAUSE 2: Missing required field: $field\n";
        }
    }
    
    // Scenario 3: Invalid status transition
    $validStatuses = ['en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee'];
    if (!in_array($existing['statut'], $validStatuses)) {
        echo "⚠️ CAUSE 3: Invalid status: {$existing['statut']}\n";
    }
    
    // Scenario 4: Test the exact API payload that the app sends
    echo "\n📤 Testing exact API payload:\n";
    
    $apiPayload = [
        'code_ops' => $testCodeOps,
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => 'admin_test',
        'validation_admin_date' => date('c')
    ];
    
    echo "Payload: " . json_encode($apiPayload, JSON_PRETTY_PRINT) . "\n";
    
    // Validate payload
    $missingFields = [];
    if (empty($apiPayload['code_ops'])) $missingFields[] = 'code_ops';
    if (empty($apiPayload['validated_by_admin_id'])) $missingFields[] = 'validated_by_admin_id';
    if (empty($apiPayload['validated_by_admin_name'])) $missingFields[] = 'validated_by_admin_name';
    
    if (!empty($missingFields)) {
        echo "⚠️ CAUSE 4: Missing payload fields: " . implode(', ', $missingFields) . "\n";
    } else {
        echo "✅ Payload fields are complete\n";
    }
    
    // Test manual update to see if it works
    echo "\n🔄 Testing manual database update:\n";
    
    try {
        $updateStmt = $db->prepare("
            UPDATE deletion_requests SET
                validated_by_admin_id = ?,
                validated_by_admin_name = ?,
                validation_admin_date = ?,
                statut = ?,
                last_modified_at = ?,
                last_modified_by = ?
            WHERE code_ops = ? AND statut = 'en_attente'
        ");
        
        $result = $updateStmt->execute([
            $apiPayload['validated_by_admin_id'],
            $apiPayload['validated_by_admin_name'],
            $apiPayload['validation_admin_date'],
            'admin_validee',
            date('Y-m-d H:i:s'),
            'admin_' . $apiPayload['validated_by_admin_name'],
            $testCodeOps
        ]);
        
        if ($result && $updateStmt->rowCount() > 0) {
            echo "✅ Manual update successful! Rows affected: " . $updateStmt->rowCount() . "\n";
        } else {
            echo "❌ Manual update failed or no rows affected\n";
            echo "   This suggests the request is not in 'en_attente' status\n";
            
            // Check current status
            $stmt->execute([$testCodeOps]);
            $current = $stmt->fetch(PDO::FETCH_ASSOC);
            echo "   Current status: {$current['statut']}\n";
            
            if ($current['statut'] !== 'en_attente') {
                echo "⚠️ CAUSE 5: Request not in 'en_attente' status - cannot validate\n";
            }
        }
    } catch (PDOException $e) {
        echo "❌ Database error: " . $e->getMessage() . "\n";
    }
    
    // Check the admin_validate.php endpoint directly
    echo "\n🔍 Checking admin_validate.php endpoint:\n";
    $endpointFile = __DIR__ . '/../api/sync/deletion_requests/admin_validate.php';
    
    if (file_exists($endpointFile)) {
        echo "✅ Endpoint file exists: $endpointFile\n";
        
        // Check file permissions
        if (is_readable($endpointFile)) {
            echo "✅ File is readable\n";
        } else {
            echo "❌ File is not readable - permission issue\n";
        }
    } else {
        echo "❌ Endpoint file missing: $endpointFile\n";
        echo "⚠️ CAUSE 6: API endpoint file not found\n";
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 POTENTIAL SOLUTIONS:\n";
    echo "1. Check if request is already validated (status != 'en_attente')\n";
    echo "2. Verify API endpoint file exists and is accessible\n";
    echo "3. Check database constraints and field validation\n";
    echo "4. Verify the request exists in the database\n";
    echo "5. Check for duplicate validation attempts\n";
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
