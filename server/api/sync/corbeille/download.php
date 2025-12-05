<?php
/**
 * API: Download Corbeille (Trash)
 * Method: GET
 * Returns: List of deleted operations in trash
 */

// CRITICAL: Disable ALL output before JSON
ob_start();

// Disable error display
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// Capture fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        ob_clean();
        http_response_code(500);
        header('Content-Type: application/json');
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
    ob_end_clean();
    http_response_code(200);
    exit();
}

// Include config for database connection
require_once __DIR__ . '/../../../config/database.php';

try {
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    $isRestored = $_GET['is_restored'] ?? null;
    
    // Build query
    $query = "SELECT * FROM operations_corbeille WHERE 1=1";
    
    if ($isRestored !== null) {
        $query .= " AND is_restored = :is_restored";
    }
    
    $query .= " ORDER BY deleted_at DESC";
    
    $stmt = $db->prepare($query);
    
    if ($isRestored !== null) {
        $stmt->bindValue(':is_restored', (int)$isRestored, PDO::PARAM_INT);
    }
    
    $stmt->execute();
    $corbeille = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[CORBEILLE] Downloaded " . count($corbeille) . " items");
    
    ob_end_clean();
    echo json_encode([
        'success' => true,
        'data' => $corbeille,
        'count' => count($corbeille)
    ]);
    
} catch (Exception $e) {
    error_log("[CORBEILLE] ERROR: " . $e->getMessage());
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e),
        'trace' => $e->getTraceAsString()
    ]);
}
