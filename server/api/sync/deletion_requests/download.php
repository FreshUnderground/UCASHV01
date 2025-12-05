<?php
/**
 * API: Download Deletion Requests
 * Method: GET
 * Returns: List of deletion requests
 */

// Disable error display
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// Capture fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erreur PHP fatale: ' . $error['message'],
            'file' => $error['file'],
            'line' => $error['line']
        ]);
    }
});

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Include config for database connection
require_once __DIR__ . '/../../../config/database.php';

try {
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    // Get all deletion requests
    $stmt = $db->query("
        SELECT * FROM deletion_requests 
        ORDER BY request_date DESC
    ");
    
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[DELETION_REQUESTS] Downloaded " . count($requests) . " requests");
    
    echo json_encode([
        'success' => true,
        'data' => $requests,
        'count' => count($requests)
    ]);
    
} catch (Exception $e) {
    error_log("[DELETION_REQUESTS] ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e)
    ]);
}
