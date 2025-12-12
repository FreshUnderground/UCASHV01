<?php
// Test script to check deletion requests in database

require_once __DIR__ . '/config/database.php';

try {
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    echo "Connected to database successfully!\n";
    
    // Check if deletion_requests table exists
    $stmt = $db->query("SHOW TABLES LIKE 'deletion_requests'");
    $tableExists = $stmt->fetch();
    
    if (!$tableExists) {
        echo "Table 'deletion_requests' does not exist!\n";
        exit(1);
    }
    
    echo "Table 'deletion_requests' exists.\n";
    
    // Get all deletion requests
    $stmt = $db->query("
        SELECT code_ops, statut, validated_by_admin_name, request_date 
        FROM deletion_requests 
        ORDER BY request_date DESC
        LIMIT 10
    ");
    
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($requests) . " deletion requests:\n";
    
    foreach ($requests as $request) {
        echo "- Code: " . $request['code_ops'] . 
             ", Status: " . $request['statut'] . 
             ", Validated by admin: " . ($request['validated_by_admin_name'] ?? 'None') . 
             ", Date: " . $request['request_date'] . "\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>