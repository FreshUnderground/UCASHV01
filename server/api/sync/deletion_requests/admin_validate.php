<?php
/**
 * API: Admin Validate Deletion Request
 * Method: POST
 * Body: {code_ops, validated_by_admin_id, validated_by_admin_name}
 */

// Enable detailed error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// Capture fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        error_log("[DELETION_REQUESTS] FATAL ERROR: " . $error['message'] . " in " . $error['file'] . " on line " . $error['line']);
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
header('Access-Control-Allow-Credentials: true');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Log ALL request information for debugging
error_log("[DELETION_REQUESTS] === NEW REQUEST ===");
error_log("[DELETION_REQUESTS] Request Method: " . ($_SERVER['REQUEST_METHOD'] ?? 'UNKNOWN'));
error_log("[DELETION_REQUESTS] Content Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'NOT SET'));
error_log("[DELETION_REQUESTS] Request URI: " . ($_SERVER['REQUEST_URI'] ?? 'UNKNOWN'));
error_log("[DELETION_REQUESTS] Query String: " . ($_SERVER['QUERY_STRING'] ?? 'NONE'));

// Log all headers
$headers = getallheaders();
error_log("[DELETION_REQUESTS] Headers: " . json_encode($headers));

// Log the raw input for debugging
$rawInput = file_get_contents('php://input');
error_log("[DELETION_REQUESTS] Raw input received: " . $rawInput);
error_log("[DELETION_REQUESTS] Raw input length: " . strlen($rawInput));

// Include config for database connection
require_once __DIR__ . '/../../../config/database.php';

try {
    // Log incoming request for debugging
    $data = json_decode($rawInput, true);
    
    error_log("[DELETION_REQUESTS] Parsed JSON data: " . json_encode($data));
    error_log("[DELETION_REQUESTS] JSON decode error: " . (json_last_error() ? json_last_error_msg() : 'NONE'));
    
    // Handle case where data is not JSON
    if ($data === null && !empty($rawInput)) {
        // Try to parse as form data or other format
        error_log("[DELETION_REQUESTS] Attempting to parse as form data...");
        parse_str($rawInput, $formData);
        error_log("[DELETION_REQUESTS] Form data parsed: " . json_encode($formData));
        $data = $formData;
    }
    
    $codeOps = $data['code_ops'] ?? $data['codeOps'] ?? null;
    $adminId = $data['validated_by_admin_id'] ?? $data['validatedByAdminId'] ?? null;
    $adminName = $data['validated_by_admin_name'] ?? $data['validatedByAdminName'] ?? null;
    
    error_log("[DELETION_REQUESTS] Extracted data - codeOps: $codeOps, adminId: $adminId, adminName: $adminName");
    
    // More detailed validation
    if (!$codeOps) {
        error_log("[DELETION_REQUESTS] ERROR: Missing code_ops field");
        error_log("[DELETION_REQUESTS] Available keys in data: " . json_encode(array_keys($data ?? [])));
    }
    
    if (!$adminId) {
        error_log("[DELETION_REQUESTS] ERROR: Missing validated_by_admin_id field");
    }
    
    if (!$adminName) {
        error_log("[DELETION_REQUESTS] ERROR: Missing validated_by_admin_name field");
    }
    
    if (!$codeOps || !$adminId || !$adminName) {
        error_log("[DELETION_REQUESTS] Missing required fields: code_ops=$codeOps, admin_id=$adminId, admin_name=$adminName");
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Champs requis manquants: code_ops, validated_by_admin_id, validated_by_admin_name',
            'received_data' => $data,
            'available_fields' => $data ? array_keys($data) : [],
            'debug_info' => [
                'code_ops_present' => !empty($codeOps),
                'admin_id_present' => !empty($adminId),
                'admin_name_present' => !empty($adminName)
            ]
        ]);
        exit();
    }
    
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    // First, check if the request exists
    $checkStmt = $db->prepare("SELECT code_ops, statut FROM deletion_requests WHERE code_ops = :code_ops");
    $checkStmt->execute([':code_ops' => $codeOps]);
    $existingRequest = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existingRequest) {
        error_log("[DELETION_REQUESTS] Request not found: $codeOps");
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Demande introuvable: $codeOps"
        ]);
        exit();
    }
    
    error_log("[DELETION_REQUESTS] Found request $codeOps with status: " . $existingRequest['statut']);
    
    // Update deletion request to admin validated status (bypass status check)
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
    
    error_log("[DELETION_REQUESTS] Update result: " . ($result ? 'true' : 'false') . ", Rows affected: " . $stmt->rowCount());
    
    if ($result && $stmt->rowCount() > 0) {
        error_log("[DELETION_REQUESTS] Request $codeOps successfully admin validated");
        
        echo json_encode([
            'success' => true,
            'message' => "Demande validée par l'administrateur",
            'code_ops' => $codeOps,
            'statut' => 'admin_validee'
        ]);
    } else {
        // This could happen if the row was already updated by another process
        error_log("[DELETION_REQUESTS] No rows updated for request $codeOps");
        
        // Let's check why no rows were affected
        $checkStmt->execute([':code_ops' => $codeOps]);
        $currentRequest = $checkStmt->fetch(PDO::FETCH_ASSOC);
        error_log("[DELETION_REQUESTS] Current request data: " . json_encode($currentRequest));
        
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => "Impossible de valider la demande",
            'debug_info' => [
                'current_status' => $currentRequest['statut'] ?? null,
                'code_ops_found' => !empty($currentRequest),
                'rows_affected' => $stmt->rowCount()
            ]
        ]);
    }
    
} catch (PDOException $e) {
    error_log("[DELETION_REQUESTS] DATABASE ERROR: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    error_log("[DELETION_REQUESTS] Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur base de données: ' . $e->getMessage(),
        'error_type' => 'PDOException'
    ]);
} catch (Exception $e) {
    error_log("[DELETION_REQUESTS] GENERAL ERROR: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    error_log("[DELETION_REQUESTS] Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e)
    ]);
}