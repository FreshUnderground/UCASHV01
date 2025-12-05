<?php
/**
 * API: Validate Deletion Request
 * Method: POST
 * Body: {code_ops, validated_by_agent_id, validated_by_agent_name, action: "approve"|"reject"}
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
    $agentId = $data['validated_by_agent_id'] ?? null;
    $agentName = $data['validated_by_agent_name'] ?? null;
    $action = $data['action'] ?? null; // "approve" or "reject"
    
    if (!$codeOps || !$agentId || !$agentName || !$action) {
        throw new Exception('Missing required fields');
    }
    
    $statut = ($action === 'approve') ? 'validee' : 'refusee';
    
    // Update deletion request
    $stmt = $db->prepare("
        UPDATE deletion_requests SET
            validated_by_agent_id = :agent_id,
            validated_by_agent_name = :agent_name,
            validation_date = :validation_date,
            statut = :statut,
            last_modified_at = :last_modified_at,
            last_modified_by = :last_modified_by
        WHERE code_ops = :code_ops
    ");
    
    $now = date('Y-m-d H:i:s');
    
    $result = $stmt->execute([
        ':agent_id' => $agentId,
        ':agent_name' => $agentName,
        ':validation_date' => $now,
        ':statut' => $statut,
        ':last_modified_at' => $now,
        ':last_modified_by' => "agent_$agentName",
        ':code_ops' => $codeOps
    ]);
    
    if ($result && $stmt->rowCount() > 0) {
        // If approved, save to corbeille BEFORE deleting
        if ($action === 'approve') {
            // Get the operation details before deleting
            $opStmt = $db->prepare("SELECT * FROM operations WHERE code_ops = ?");
            $opStmt->execute([$codeOps]);
            $operation = $opStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($operation) {
                // Save to operations_corbeille
                $corbeilleStmt = $db->prepare("
                    INSERT INTO operations_corbeille (
                        original_operation_id, code_ops, type,
                        shop_source_id, shop_source_designation,
                        shop_destination_id, shop_destination_designation,
                        agent_id, agent_username,
                        client_id, client_nom,
                        montant_brut, commission, montant_net, devise,
                        mode_paiement, destinataire, telephone_destinataire,
                        reference, sim_numero, statut, notes, observation,
                        date_op, date_validation,
                        created_at_original, last_modified_at_original, last_modified_by_original,
                        validated_by_agent_id, validated_by_agent_name,
                        deleted_at, is_restored, is_synced
                    ) VALUES (
                        :original_operation_id, :code_ops, :type,
                        :shop_source_id, :shop_source_designation,
                        :shop_destination_id, :shop_destination_designation,
                        :agent_id, :agent_username,
                        :client_id, :client_nom,
                        :montant_brut, :commission, :montant_net, :devise,
                        :mode_paiement, :destinataire, :telephone_destinataire,
                        :reference, :sim_numero, :statut, :notes, :observation,
                        :date_op, :date_validation,
                        :created_at_original, :last_modified_at_original, :last_modified_by_original,
                        :validated_by_agent_id, :validated_by_agent_name,
                        :deleted_at, :is_restored, :is_synced
                    )
                ");
                
                // Map operation type from enum to string
                $typeMap = [
                    0 => 'TRANSFERT_NATIONAL',
                    1 => 'TRANSFERT_INTERNATIONAL',
                    2 => 'DEPOT',
                    3 => 'RETRAIT',
                    4 => 'CHANGE',
                    5 => 'PAIEMENT',
                    6 => 'VIREMENT',
                    7 => 'FLOT'
                ];
                $type = $typeMap[$operation['type']] ?? 'TRANSFERT_NATIONAL';
                
                // Map mode_paiement from enum to string
                $modePaiementMap = [
                    0 => 'cash',
                    1 => 'mobileMoney',
                    2 => 'banque',
                    3 => 'cheque'
                ];
                $modePaiement = $modePaiementMap[$operation['mode_paiement']] ?? 'cash';
                
                // Map statut from enum to string
                $statutMap = [
                    0 => 'terminee',
                    1 => 'enAttente',
                    2 => 'annulee'
                ];
                $statutStr = $statutMap[$operation['statut']] ?? 'terminee';
                
                $corbeilleStmt->execute([
                    ':original_operation_id' => $operation['id'],
                    ':code_ops' => $operation['code_ops'],
                    ':type' => $type,
                    ':shop_source_id' => $operation['shop_source_id'],
                    ':shop_source_designation' => $operation['shop_source_designation'],
                    ':shop_destination_id' => $operation['shop_destination_id'],
                    ':shop_destination_designation' => $operation['shop_destination_designation'],
                    ':agent_id' => $operation['agent_id'],
                    ':agent_username' => $operation['agent_username'],
                    ':client_id' => $operation['client_id'],
                    ':client_nom' => $operation['client_nom'],
                    ':montant_brut' => $operation['montant_brut'],
                    ':commission' => $operation['commission'],
                    ':montant_net' => $operation['montant_net'],
                    ':devise' => $operation['devise'],
                    ':mode_paiement' => $modePaiement,
                    ':destinataire' => $operation['destinataire'],
                    ':telephone_destinataire' => $operation['telephone_destinataire'],
                    ':reference' => $operation['reference'],
                    ':sim_numero' => $operation['sim_numero'],
                    ':statut' => $statutStr,
                    ':notes' => $operation['notes'],
                    ':observation' => $operation['observation'],
                    ':date_op' => $operation['date_op'],
                    ':date_validation' => $operation['date_validation'],
                    ':created_at_original' => $operation['created_at'],
                    ':last_modified_at_original' => $operation['last_modified_at'],
                    ':last_modified_by_original' => $operation['last_modified_by'],
                    ':validated_by_agent_id' => $agentId,
                    ':validated_by_agent_name' => $agentName,
                    ':deleted_at' => $now,
                    ':is_restored' => 0,
                    ':is_synced' => 1
                ]);
                
                error_log("[DELETION_REQUESTS] Operation $codeOps saved to corbeille");
            }
            
            // Now delete the operation
            $deleteStmt = $db->prepare("DELETE FROM operations WHERE code_ops = ?");
            $deleteStmt->execute([$codeOps]);
            error_log("[DELETION_REQUESTS] Operation $codeOps deleted from server");
        }
        
        error_log("[DELETION_REQUESTS] Request $codeOps validated: $statut");
        
        echo json_encode([
            'success' => true,
            'message' => "Request validated: $statut",
            'code_ops' => $codeOps,
            'statut' => $statut
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
