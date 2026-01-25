<?php
/**
 * Test Admin Validation UI - Simulate exact app behavior
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Testing admin validation UI behavior...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    // Reset the test request to en_attente state
    $resetStmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_admin_id = NULL,
            validated_by_admin_name = NULL,
            validation_admin_date = NULL,
            statut = 'en_attente',
            last_modified_at = NOW(),
            is_synced = 0
        WHERE code_ops = '251211225322019'
    ");
    $resetStmt->execute();
    echo "🔄 Reset request to en_attente state\n\n";
    
    // Show current state
    $stmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = '251211225322019'");
    $stmt->execute();
    $request = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "📋 Current state:\n";
    echo "   Status: {$request['statut']}\n";
    echo "   Admin validator: " . ($request['validated_by_admin_name'] ?? 'NULL') . "\n";
    echo "   Is synced: " . ($request['is_synced'] ? 'YES' : 'NO') . "\n\n";
    
    // Test the exact API endpoint that the app calls
    echo "🧪 Testing admin validation API endpoint...\n";
    
    $apiUrl = 'https://safdal.investee-group.com/server/api/sync/deletion_requests/admin_validate.php';
    
    $postData = json_encode([
        'code_ops' => '251211225322019',
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => 'admin_test',
        'validation_admin_date' => date('c')
    ]);
    
    echo "📤 Sending POST request to: $apiUrl\n";
    echo "📦 Data: $postData\n\n";
    
    // Use cURL to test the API
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $apiUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Content-Length: ' . strlen($postData)
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    echo "📡 HTTP Response Code: $httpCode\n";
    
    if ($error) {
        echo "❌ cURL Error: $error\n";
    } else {
        echo "📥 Response: $response\n\n";
        
        // Parse response
        $responseData = json_decode($response, true);
        if ($responseData) {
            if ($responseData['success'] ?? false) {
                echo "✅ API call successful!\n";
            } else {
                echo "❌ API call failed: " . ($responseData['message'] ?? 'Unknown error') . "\n";
                if (isset($responseData['debug_info'])) {
                    echo "🔍 Debug info: " . json_encode($responseData['debug_info']) . "\n";
                }
            }
        } else {
            echo "❌ Invalid JSON response\n";
        }
    }
    
    // Check database state after API call
    echo "\n📋 Database state after API call:\n";
    $stmt->execute();
    $updatedRequest = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "   Status: {$updatedRequest['statut']}\n";
    echo "   Admin validator: " . ($updatedRequest['validated_by_admin_name'] ?? 'NULL') . "\n";
    echo "   Validation date: " . ($updatedRequest['validation_admin_date'] ?? 'NULL') . "\n";
    echo "   Last modified: {$updatedRequest['last_modified_at']}\n";
    echo "   Is synced: " . ($updatedRequest['is_synced'] ? 'YES' : 'NO') . "\n";
    
    // Compare states
    echo "\n🔍 Analysis:\n";
    if ($updatedRequest['statut'] === 'admin_validee') {
        echo "✅ Status correctly updated to admin_validee\n";
    } else {
        echo "❌ Status NOT updated (still: {$updatedRequest['statut']})\n";
    }
    
    if ($updatedRequest['validated_by_admin_name']) {
        echo "✅ Admin validator set: {$updatedRequest['validated_by_admin_name']}\n";
    } else {
        echo "❌ Admin validator NOT set\n";
    }
    
    if ($updatedRequest['validation_admin_date']) {
        echo "✅ Validation date set: {$updatedRequest['validation_admin_date']}\n";
    } else {
        echo "❌ Validation date NOT set\n";
    }
    
    // Test if this appears in agent pending list
    echo "\n🔍 Checking agent pending requests...\n";
    $agentStmt = $db->query("SELECT code_ops, statut FROM deletion_requests WHERE statut = 'admin_validee'");
    $agentRequests = $agentStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "📋 Requests pending agent validation: " . count($agentRequests) . "\n";
    foreach ($agentRequests as $agentReq) {
        echo "   - {$agentReq['code_ops']}: {$agentReq['statut']}\n";
    }
    
    if (count($agentRequests) > 0) {
        echo "✅ Request is now visible for agent validation\n";
    } else {
        echo "❌ Request is NOT visible for agent validation\n";
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 CONCLUSION:\n";
    if ($updatedRequest['statut'] === 'admin_validee' && count($agentRequests) > 0) {
        echo "✅ Admin validation is working correctly!\n";
        echo "   Next step: Agent needs to validate to actually delete the operation\n";
    } else {
        echo "❌ Admin validation has issues that need to be fixed\n";
    }
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
