<?php
/**
 * API: Update Operation by CodeOps
 * Method: POST
 * Body: Operation JSON with code_ops as unique identifier
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
    error_log("[UPDATE] Requête reçue: " . json_encode($data));
    
    if (!isset($data['code_ops']) || empty($data['code_ops'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Code opération requis'
        ]);
        exit;
    }
    
    $codeOps = $data['code_ops'];
    
    // Log du CodeOps
    error_log("[UPDATE] Recherche opération avec code_ops: $codeOps");
    
    // Check if operation exists
    $stmt = $db->prepare("SELECT id FROM operations WHERE code_ops = ?");
    $stmt->execute([$codeOps]);
    $operation = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$operation) {
        error_log("[UPDATE] ERREUR: Opération non trouvée - code_ops: $codeOps");
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Opération non trouvée avec code_ops: ' . $codeOps
        ]);
        exit;
    }
    
    // Update operation
    error_log("[UPDATE] Mise à jour opération ID: {$operation['id']}, code_ops: $codeOps");
    $updateStmt = $db->prepare("
        UPDATE operations SET
            montant_brut = :montant_brut,
            montant_net = :montant_net,
            commission = :commission,
            destinataire = :destinataire,
            observation = :observation,
            notes = :notes,
            last_modified_at = :last_modified_at,
            last_modified_by = :last_modified_by,
            is_synced = 1,
            synced_at = NOW()
        WHERE code_ops = :code_ops
    ");
    
    $result = $updateStmt->execute([
        ':montant_brut' => $data['montant_brut'] ?? $data['montantBrut'] ?? 0,
        ':montant_net' => $data['montant_net'] ?? $data['montantNet'] ?? 0,
        ':commission' => $data['commission'] ?? 0,
        ':destinataire' => $data['destinataire'] ?? null,
        ':observation' => $data['observation'] ?? null,
        ':notes' => $data['notes'] ?? null,
        ':last_modified_at' => $data['last_modified_at'] ?? $data['lastModifiedAt'] ?? date('Y-m-d H:i:s'),
        ':last_modified_by' => $data['last_modified_by'] ?? $data['lastModifiedBy'] ?? 'system',
        ':code_ops' => $codeOps
    ]);
    
    if ($result) {
        error_log("[UPDATE] ✅ Opération mise à jour avec succès - code_ops: $codeOps");
        
        // Get updated operation
        $getStmt = $db->prepare("SELECT * FROM operations WHERE code_ops = ?");
        $getStmt->execute([$codeOps]);
        $updatedOp = $getStmt->fetch(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true,
            'message' => 'Opération mise à jour avec succès',
            'code_ops' => $codeOps,
            'operation' => $updatedOp
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erreur lors de la mise à jour'
        ]);
    }
} catch (Exception $e) {
    error_log("[UPDATE] ERREUR EXCEPTION: " . $e->getMessage());
    error_log("[UPDATE] TRACE: " . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
}
