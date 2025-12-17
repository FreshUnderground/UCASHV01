<?php
/**
 * Debug Agent Validation Empty List Issue
 * Investigate why agent deletion validation shows no items
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

require_once __DIR__ . '/../config/database.php';

try {
    echo "🔍 Debugging Agent Validation Empty List Issue...\n\n";
    
    $db = $pdo;
    
    // STEP 1: Check all deletion requests
    echo "📋 STEP 1: Checking all deletion requests in database...\n";
    $allStmt = $db->query("SELECT code_ops, statut, validated_by_admin_id, validated_by_admin_name, validated_by_agent_id, validated_by_agent_name, created_at FROM deletion_requests ORDER BY created_at DESC LIMIT 10");
    $allRequests = $allStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Total deletion requests found: " . count($allRequests) . "\n\n";
    
    foreach ($allRequests as $req) {
        echo "📄 Code: {$req['code_ops']}\n";
        echo "   Statut: '{$req['statut']}'\n";
        echo "   Admin validator: " . ($req['validated_by_admin_name'] ?? 'NULL') . "\n";
        echo "   Agent validator: " . ($req['validated_by_agent_name'] ?? 'NULL') . "\n";
        echo "   Created: {$req['created_at']}\n";
        echo "   ---\n";
    }
    
    // STEP 2: Check specifically for admin_validee status
    echo "\n📋 STEP 2: Checking requests with 'admin_validee' status (should show for agents)...\n";
    $adminValidatedStmt = $db->query("SELECT code_ops, statut, validated_by_admin_name, created_at FROM deletion_requests WHERE statut = 'admin_validee'");
    $adminValidated = $adminValidatedStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Requests with 'admin_validee' status: " . count($adminValidated) . "\n";
    
    if (count($adminValidated) > 0) {
        echo "✅ Found admin validated requests (these should show for agents):\n";
        foreach ($adminValidated as $req) {
            echo "   📄 {$req['code_ops']} - validated by: {$req['validated_by_admin_name']}\n";
        }
    } else {
        echo "❌ NO requests with 'admin_validee' status found!\n";
        echo "   This explains why agent list is empty.\n";
    }
    
    // STEP 3: Check for requests with empty or incorrect status
    echo "\n📋 STEP 3: Checking for requests with problematic status...\n";
    $problemStmt = $db->query("SELECT code_ops, statut, validated_by_admin_name FROM deletion_requests WHERE statut = '' OR statut IS NULL OR statut NOT IN ('en_attente', 'admin_validee', 'agent_validee', 'refusee', 'annulee')");
    $problemRequests = $problemStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Requests with problematic status: " . count($problemRequests) . "\n";
    
    if (count($problemRequests) > 0) {
        echo "⚠️ Found requests with problematic status:\n";
        foreach ($problemRequests as $req) {
            echo "   📄 {$req['code_ops']} - status: '{$req['statut']}' - admin: " . ($req['validated_by_admin_name'] ?? 'NULL') . "\n";
        }
    }
    
    // STEP 4: Check for requests that should be admin_validee
    echo "\n📋 STEP 4: Checking for requests that have admin validator but wrong status...\n";
    $shouldBeAdminValidatedStmt = $db->query("SELECT code_ops, statut, validated_by_admin_name, validated_by_agent_name FROM deletion_requests WHERE validated_by_admin_name IS NOT NULL AND validated_by_agent_name IS NULL AND statut != 'admin_validee'");
    $shouldBeAdminValidated = $shouldBeAdminValidatedStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Requests that should be 'admin_validee': " . count($shouldBeAdminValidated) . "\n";
    
    if (count($shouldBeAdminValidated) > 0) {
        echo "🔧 Found requests that need status correction:\n";
        foreach ($shouldBeAdminValidated as $req) {
            echo "   📄 {$req['code_ops']} - current status: '{$req['statut']}' - admin: {$req['validated_by_admin_name']}\n";
        }
        
        // STEP 5: Fix the status issues
        echo "\n🔧 STEP 5: Fixing status issues...\n";
        
        $fixStmt = $db->prepare("UPDATE deletion_requests SET statut = 'admin_validee' WHERE validated_by_admin_name IS NOT NULL AND validated_by_agent_name IS NULL AND statut != 'admin_validee'");
        $fixResult = $fixStmt->execute();
        
        if ($fixResult && $fixStmt->rowCount() > 0) {
            echo "✅ Fixed {$fixStmt->rowCount()} requests status to 'admin_validee'\n";
            
            // Verify the fix
            $verifyStmt = $db->query("SELECT code_ops, statut FROM deletion_requests WHERE statut = 'admin_validee'");
            $verifiedRequests = $verifyStmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo "✅ Now {count($verifiedRequests)} requests have 'admin_validee' status:\n";
            foreach ($verifiedRequests as $req) {
                echo "   📄 {$req['code_ops']}\n";
            }
        } else {
            echo "❌ No requests were fixed\n";
        }
    }
    
    // STEP 6: Check specific problematic request
    echo "\n📋 STEP 6: Checking specific request '251211224943822'...\n";
    $specificStmt = $db->prepare("SELECT * FROM deletion_requests WHERE code_ops = '251211224943822'");
    $specificStmt->execute();
    $specificRequest = $specificStmt->fetch(PDO::FETCH_ASSOC);
    
    if ($specificRequest) {
        echo "📄 Found request 251211224943822:\n";
        echo "   Statut: '{$specificRequest['statut']}'\n";
        echo "   Admin ID: " . ($specificRequest['validated_by_admin_id'] ?? 'NULL') . "\n";
        echo "   Admin Name: " . ($specificRequest['validated_by_admin_name'] ?? 'NULL') . "\n";
        echo "   Agent ID: " . ($specificRequest['validated_by_agent_id'] ?? 'NULL') . "\n";
        echo "   Agent Name: " . ($specificRequest['validated_by_agent_name'] ?? 'NULL') . "\n";
        echo "   Created: {$specificRequest['created_at']}\n";
        echo "   Last Modified: {$specificRequest['last_modified_at']}\n";
        
        // Fix this specific request if needed
        if (empty($specificRequest['statut']) && !empty($specificRequest['validated_by_admin_name'])) {
            echo "\n🔧 Fixing specific request status...\n";
            $fixSpecificStmt = $db->prepare("UPDATE deletion_requests SET statut = 'admin_validee' WHERE code_ops = '251211224943822'");
            $fixSpecificResult = $fixSpecificStmt->execute();
            
            if ($fixSpecificResult && $fixSpecificStmt->rowCount() > 0) {
                echo "✅ Fixed request 251211224943822 status to 'admin_validee'\n";
            }
        }
    } else {
        echo "❌ Request 251211224943822 not found\n";
    }
    
    // STEP 7: Final summary for agent validation
    echo "\n📋 STEP 7: Final summary - What agents should see...\n";
    $finalAgentStmt = $db->query("SELECT code_ops, operation_type, montant, devise, validated_by_admin_name FROM deletion_requests WHERE statut = 'admin_validee' ORDER BY created_at DESC");
    $finalAgentRequests = $finalAgentStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "🎯 AGENT VALIDATION LIST (statut = 'admin_validee'):\n";
    echo "Total requests for agent validation: " . count($finalAgentRequests) . "\n\n";
    
    if (count($finalAgentRequests) > 0) {
        echo "✅ Requests that should appear in agent validation list:\n";
        foreach ($finalAgentRequests as $req) {
            echo "   📄 {$req['code_ops']} - {$req['operation_type']} - {$req['montant']} {$req['devise']} - Admin: {$req['validated_by_admin_name']}\n";
        }
    } else {
        echo "❌ NO requests found for agent validation!\n";
        echo "   Check if:\n";
        echo "   1. Admin validations are working correctly\n";
        echo "   2. Status updates are being saved properly\n";
        echo "   3. Database sync is working\n";
    }
    
    echo "\n" . str_repeat("=", 60) . "\n";
    echo "🎯 DIAGNOSIS COMPLETE\n";
    echo str_repeat("=", 60) . "\n";
    
} catch (Exception $e) {
    echo "💥 ERROR: " . $e->getMessage() . "\n";
    echo "   File: " . $e->getFile() . "\n";
    echo "   Line: " . $e->getLine() . "\n";
}
?>
