<?php
/**
 * Compare App API call vs Test Script to find discrepancy
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

// Include database config
require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Comparing App vs Test Script API calls...\n\n";
    
    // Use the $pdo connection from config
    $db = $pdo;
    
    echo "=== TEST SCRIPT CALL (WORKING) ===\n";
    echo "URL: https://safdal.investee-group.com/server/database/test_admin_validation_ui.php\n";
    echo "Method: Direct PHP execution\n";
    echo "Payload: Hardcoded in script\n\n";
    
    echo "=== APP API CALL (FAILING) ===\n";
    echo "URL: https://safdal.investee-group.com/server/api/sync/deletion_requests/admin_validate.php\n";
    echo "Method: HTTP POST from Flutter app\n";
    echo "Content-Type: application/json\n\n";
    
    // Check if the API endpoint exists
    $apiEndpoint = __DIR__ . '/../api/sync/deletion_requests/admin_validate.php';
    echo "🔍 Checking API endpoint: $apiEndpoint\n";
    
    if (file_exists($apiEndpoint)) {
        echo "✅ API endpoint exists\n";
        
        // Read the API endpoint content to understand its logic
        $apiContent = file_get_contents($apiEndpoint);
        
        // Check for common issues
        echo "\n🔍 Analyzing API endpoint:\n";
        
        // Check for JSON input handling
        if (strpos($apiContent, 'php://input') !== false) {
            echo "✅ Reads from php://input (correct for JSON POST)\n";
        } else {
            echo "❌ Does not read from php://input (may not handle JSON)\n";
        }
        
        // Check for Content-Type validation
        if (strpos($apiContent, 'Content-Type') !== false || strpos($apiContent, 'content-type') !== false) {
            echo "⚠️ May have Content-Type validation (could reject app requests)\n";
        }
        
        // Check for required fields validation
        if (strpos($apiContent, 'code_ops') !== false) {
            echo "✅ Validates code_ops field\n";
        }
        
        if (strpos($apiContent, 'validated_by_admin_id') !== false) {
            echo "✅ Validates validated_by_admin_id field\n";
        }
        
        // Check for status validation
        if (strpos($apiContent, 'en_attente') !== false) {
            echo "✅ Checks for 'en_attente' status\n";
        }
        
    } else {
        echo "❌ API endpoint does not exist!\n";
        echo "⚠️ This is likely the main issue - the app is calling a non-existent endpoint\n";
        
        // Check if the directory structure exists
        $apiDir = dirname($apiEndpoint);
        if (!is_dir($apiDir)) {
            echo "❌ API directory does not exist: $apiDir\n";
            echo "📁 Creating directory structure...\n";
            
            if (mkdir($apiDir, 0755, true)) {
                echo "✅ Directory created successfully\n";
            } else {
                echo "❌ Failed to create directory\n";
            }
        }
    }
    
    // Test the exact payload that the app would send
    echo "\n🧪 Testing app-style API call:\n";
    
    $testCodeOps = '251211225017939';
    
    // Reset the request to en_attente for testing
    $resetStmt = $db->prepare("
        UPDATE deletion_requests SET 
            statut = 'en_attente',
            validated_by_admin_id = NULL,
            validated_by_admin_name = NULL,
            validation_admin_date = NULL
        WHERE code_ops = ?
    ");
    $resetStmt->execute([$testCodeOps]);
    echo "🔄 Reset request to en_attente for testing\n";
    
    // Simulate the exact API call that the app makes
    $appPayload = json_encode([
        'code_ops' => $testCodeOps,
        'validated_by_admin_id' => 1,
        'validated_by_admin_name' => 'admin',
        'validation_admin_date' => date('c')
    ]);
    
    echo "📤 App payload: $appPayload\n";
    
    if (file_exists($apiEndpoint)) {
        // Test with cURL to simulate app behavior
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://safdal.investee-group.com/server/api/sync/deletion_requests/admin_validate.php');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $appPayload);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($appPayload)
        ]);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        echo "📡 HTTP Response Code: $httpCode\n";
        
        if ($error) {
            echo "❌ cURL Error: $error\n";
        } else {
            echo "📥 Response: $response\n";
            
            if ($httpCode === 400) {
                echo "⚠️ CONFIRMED: App-style call returns HTTP 400\n";
                echo "🔍 This confirms the issue is in the API endpoint logic\n";
            } elseif ($httpCode === 200) {
                echo "✅ App-style call works - issue may be elsewhere\n";
            }
        }
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 DIAGNOSIS:\n";
    
    if (!file_exists($apiEndpoint)) {
        echo "❌ MAIN ISSUE: API endpoint file missing\n";
        echo "   Solution: Copy admin_validate.php to the correct location\n";
    } else {
        echo "✅ API endpoint exists\n";
        echo "🔍 Issue likely in endpoint logic or request handling\n";
        echo "   - Check JSON parsing\n";
        echo "   - Check field validation\n";
        echo "   - Check status validation logic\n";
    }
    
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 FATAL ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
    exit(1);
}
?>
