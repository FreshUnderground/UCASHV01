<?php
/**
 * API: Upload Deletion Requests
 * Method: POST
 * Body: Array of deletion requests JSON
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
    $requests = json_decode($json, true);
    
    if (!is_array($requests)) {
        throw new Exception('Invalid data format - expected array');
    }
    
    $inserted = 0;
    $updated = 0;
    
    foreach ($requests as $request) {
        $codeOps = $request['code_ops'] ?? $request['codeOps'] ?? null;
        
        if (!$codeOps) {
            error_log("[DELETION_REQUESTS] Skipping request without code_ops");
            continue;
        }
        
        // Check if exists
        $stmt = $db->prepare("SELECT id FROM deletion_requests WHERE code_ops = ?");
        $stmt->execute([$codeOps]);
        $exists = $stmt->fetch();
        
        if ($exists) {
            // Update
            $stmt = $db->prepare("
                UPDATE deletion_requests SET
                    operation_id = :operation_id,
                    operation_type = :operation_type,
                    montant = :montant,
                    devise = :devise,
                    destinataire = :destinataire,
                    expediteur = :expediteur,
                    client_nom = :client_nom,
                    requested_by_admin_id = :requested_by_admin_id,
                    requested_by_admin_name = :requested_by_admin_name,
                    request_date = :request_date,
                    reason = :reason,
                    statut = :statut,
                    validated_by_agent_id = :validated_by_agent_id,
                    validated_by_agent_name = :validated_by_agent_name,
                    validation_date = :validation_date,
                    last_modified_at = :last_modified_at,
                    last_modified_by = :last_modified_by
                WHERE code_ops = :code_ops
            ");
            $updated++;
        } else {
            // Insert
            $stmt = $db->prepare("
                INSERT INTO deletion_requests (
                    code_ops, operation_id, operation_type, montant, devise,
                    destinataire, expediteur, client_nom,
                    requested_by_admin_id, requested_by_admin_name, request_date,
                    reason, statut,
                    validated_by_agent_id, validated_by_agent_name, validation_date,
                    last_modified_at, last_modified_by
                ) VALUES (
                    :code_ops, :operation_id, :operation_type, :montant, :devise,
                    :destinataire, :expediteur, :client_nom,
                    :requested_by_admin_id, :requested_by_admin_name, :request_date,
                    :reason, :statut,
                    :validated_by_agent_id, :validated_by_agent_name, :validation_date,
                    :last_modified_at, :last_modified_by
                )
            ");
            $inserted++;
        }
        
        $stmt->execute([
            ':code_ops' => $codeOps,
            ':operation_id' => $request['operation_id'] ?? $request['operationId'] ?? null,
            ':operation_type' => $request['operation_type'] ?? $request['operationType'] ?? null,
            ':montant' => $request['montant'] ?? 0,
            ':devise' => $request['devise'] ?? 'USD',
            ':destinataire' => $request['destinataire'] ?? null,
            ':expediteur' => $request['expediteur'] ?? null,
            ':client_nom' => $request['client_nom'] ?? $request['clientNom'] ?? null,
            ':requested_by_admin_id' => $request['requested_by_admin_id'] ?? $request['requestedByAdminId'] ?? null,
            ':requested_by_admin_name' => $request['requested_by_admin_name'] ?? $request['requestedByAdminName'] ?? null,
            ':request_date' => $request['request_date'] ?? $request['requestDate'] ?? date('Y-m-d H:i:s'),
            ':reason' => $request['reason'] ?? null,
            ':statut' => $request['statut'] ?? 'en_attente',
            ':validated_by_agent_id' => $request['validated_by_agent_id'] ?? $request['validatedByAgentId'] ?? null,
            ':validated_by_agent_name' => $request['validated_by_agent_name'] ?? $request['validatedByAgentName'] ?? null,
            ':validation_date' => $request['validation_date'] ?? $request['validationDate'] ?? null,
            ':last_modified_at' => $request['last_modified_at'] ?? $request['lastModifiedAt'] ?? date('Y-m-d H:i:s'),
            ':last_modified_by' => $request['last_modified_by'] ?? $request['lastModifiedBy'] ?? 'system'
        ]);
    }
    
    error_log("[DELETION_REQUESTS] Uploaded: $inserted inserted, $updated updated");
    
    echo json_encode([
        'success' => true,
        'message' => "Uploaded successfully",
        'inserted' => $inserted,
        'updated' => $updated
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
