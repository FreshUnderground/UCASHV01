<?php
/**
 * API: Admin Validate Deletion Request
 * Method: POST
 * Body: {code_ops, validated_by_admin_id, validated_by_admin_name}
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
header('Access-Control-Allow-Methods: POST, OPTIONS');
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
    
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    $codeOps = $data['code_ops'] ?? null;
    $adminId = $data['validated_by_admin_id'] ?? null;
    $adminName = $data['validated_by_admin_name'] ?? null;
    
    if (!$codeOps || !$adminId || !$adminName) {
        throw new Exception('Missing required fields');
    }
    
    // Update deletion request to admin validated status
    $stmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_admin_id = :admin_id,
            validated_by_admin_name = :admin_name,
            validation_admin_date = :validation_admin_date,
            statut = :statut,
            last_modified_at = :last_modified_at,
            last_modified_by = :last_modified_by
        WHERE code_ops = :code_ops
    ");
    
    $now = date('Y-m-d H:i:s');
    
    $result = $stmt->execute([
        ':admin_id' => $adminId,
        ':admin_name' => $adminName,
        ':validation_admin_date' => $now,
        ':statut' => 'admin_validee',
        ':last_modified_at' => $now,
        ':last_modified_by' => "admin_$adminName",
        ':code_ops' => $codeOps
    ]);
    
    if ($result && $stmt->rowCount() > 0) {
        error_log("[DELETION_REQUESTS] Request $codeOps admin validated");
        
        echo json_encode([
            'success' => true,
            'message' => "Request admin validated",
            'code_ops' => $codeOps,
            'statut' => 'admin_validee'
        ]);
    } else {
        throw new Exception("Request not found or already validated");
    }
    
} catch (Exception $e) {
    error_log("[DELETION_REQUESTS] ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e)
    ]);
}