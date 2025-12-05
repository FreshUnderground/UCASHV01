<?php
/**
 * API: Delete Operation by CodeOps
 * Method: POST
 * Body: {"codeOps": "251202160848312"}
 */

// Disable error display (errors should only go to error_log)
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

// Include Database class and config
require_once __DIR__ . '/../../../classes/Database.php';
require_once __DIR__ . '/../../../config/database.php';

try {
    $database = Database::getInstance();
    $db = $database->getConnection();
    
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    // Log de la requête reçue
    error_log("[DELETE] Requête reçue: " . json_encode($data));
    
    if (!isset($data['codeOps']) || empty($data['codeOps'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'CodeOps requis'
        ]);
        exit;
    }
    
    $codeOps = $data['codeOps'];
    
    // Log du CodeOps
    error_log("[DELETE] Recherche opération avec code_ops: $codeOps");
    
    // Check if operation exists
    $stmt = $db->prepare("SELECT id FROM operations WHERE code_ops = ?");
    $stmt->execute([$codeOps]);
    $operation = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$operation) {
        error_log("[DELETE] Opération non trouvée (peut-être déjà supprimée) - code_ops: $codeOps");
        // Return success anyway since the operation doesn't exist on server
        echo json_encode([
            'success' => true,
            'message' => 'Opération déjà supprimée ou n\'existe pas',
            'code_ops' => $codeOps
        ]);
        exit;
    }
    
    // Delete operation
    error_log("[DELETE] Suppression opération ID: {$operation['id']}, code_ops: $codeOps");
    $deleteStmt = $db->prepare("DELETE FROM operations WHERE code_ops = ?");
    $result = $deleteStmt->execute([$codeOps]);
    
    if ($result) {
        error_log("[DELETE] ✅ Opération supprimée avec succès - code_ops: $codeOps");
        
        echo json_encode([
            'success' => true,
            'message' => 'Opération supprimée avec succès',
            'code_ops' => $codeOps
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erreur lors de la suppression'
        ]);
    }
} catch (Exception $e) {
    error_log("[DELETE] ERREUR EXCEPTION: " . $e->getMessage());
    error_log("[DELETE] TRACE: " . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
}
