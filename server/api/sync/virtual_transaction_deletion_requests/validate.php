<?php
/**
 * API: Agent Validate Virtual Transaction Deletion Request
 * Method: POST
 * Body: {reference, validated_by_agent_id, validated_by_agent_name, approve}
 */

error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$rawInput = file_get_contents('php://input');
error_log("[VT_DELETION_REQUESTS] Agent validate - Raw input: " . $rawInput);

require_once __DIR__ . '/../../../config/database.php';

try {
    $data = json_decode($rawInput, true);
    
    if ($data === null && !empty($rawInput)) {
        parse_str($rawInput, $formData);
        $data = $formData;
    }
    
    $reference = $data['reference'] ?? null;
    $agentId = $data['validated_by_agent_id'] ?? null;
    $agentName = $data['validated_by_agent_name'] ?? null;
    $approve = $data['approve'] ?? null;
    
    error_log("[VT_DELETION_REQUESTS] Agent validation - reference: $reference, agentId: $agentId, agentName: $agentName, approve: " . ($approve ? 'true' : 'false'));
    
    if (!$reference || $agentId === null || !$agentName || $approve === null) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Champs requis manquants: reference, validated_by_agent_id, validated_by_agent_name, approve'
        ]);
        exit();
    }
    
    $db = $pdo;
    
    // Check if the request exists and is admin validated
    $checkStmt = $db->prepare("SELECT * FROM virtual_transaction_deletion_requests WHERE reference = :reference");
    $checkStmt->execute([':reference' => $reference]);
    $existingRequest = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existingRequest) {
        error_log("[VT_DELETION_REQUESTS] Request not found: $reference");
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Demande introuvable: $reference"
        ]);
        exit();
    }
    
    if ($existingRequest['statut'] !== 'admin_validee') {
        error_log("[VT_DELETION_REQUESTS] Request not admin validated: $reference (status: " . $existingRequest['statut'] . ")");
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => "Cette demande n'est pas validée par un administrateur"
        ]);
        exit();
    }
    
    $db->beginTransaction();
    
    try {
        $newStatus = $approve ? 'agent_validee' : 'refusee';
        $now = date('Y-m-d H:i:s');
        
        // Update the deletion request
        $stmt = $db->prepare("
            UPDATE virtual_transaction_deletion_requests SET
                validated_by_agent_id = :agent_id,
                validated_by_agent_name = :agent_name,
                validation_date = :validation_date,
                statut = :statut,
                last_modified_at = :last_modified_at,
                last_modified_by = :last_modified_by
            WHERE reference = :reference
        ");
        
        $result = $stmt->execute([
            ':agent_id' => $agentId,
            ':agent_name' => $agentName,
            ':validation_date' => $now,
            ':statut' => $newStatus,
            ':last_modified_at' => $now,
            ':last_modified_by' => "agent_$agentName",
            ':reference' => $reference
        ]);
        
        if (!$result || $stmt->rowCount() === 0) {
            throw new Exception("Impossible de mettre à jour la demande de suppression");
        }
        
        // If approved, move the virtual transaction to corbeille and delete from main table
        if ($approve) {
            // Find the virtual transaction
            $vtStmt = $db->prepare("SELECT * FROM virtual_transactions WHERE reference = :reference");
            $vtStmt->execute([':reference' => $reference]);
            $virtualTransaction = $vtStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($virtualTransaction) {
                // Insert into corbeille
                $corbeilleStmt = $db->prepare("
                    INSERT INTO virtual_transactions_corbeille (
                        reference, virtual_transaction_id, montant_virtuel, frais, montant_cash, devise,
                        sim_numero, shop_id, shop_designation, agent_id, agent_username,
                        client_nom, client_telephone, statut, date_enregistrement, date_validation,
                        notes, is_administrative, deleted_by_agent_id, deleted_by_agent_name,
                        deletion_date, deletion_reason, last_modified_at, last_modified_by
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ");
                
                $corbeilleStmt->execute([
                    $virtualTransaction['reference'],
                    $virtualTransaction['id'],
                    $virtualTransaction['montant_virtuel'],
                    $virtualTransaction['frais'] ?? 0,
                    $virtualTransaction['montant_cash'],
                    $virtualTransaction['devise'] ?? 'USD',
                    $virtualTransaction['sim_numero'],
                    $virtualTransaction['shop_id'],
                    $virtualTransaction['shop_designation'],
                    $virtualTransaction['agent_id'],
                    $virtualTransaction['agent_username'],
                    $virtualTransaction['client_nom'],
                    $virtualTransaction['client_telephone'],
                    $virtualTransaction['statut'],
                    $virtualTransaction['date_enregistrement'],
                    $virtualTransaction['date_validation'],
                    $virtualTransaction['notes'],
                    $virtualTransaction['is_administrative'] ?? false,
                    $agentId,
                    $agentName,
                    $now,
                    $existingRequest['reason'],
                    $now,
                    "agent_$agentName"
                ]);
                
                // Delete from main table
                $deleteStmt = $db->prepare("DELETE FROM virtual_transactions WHERE reference = :reference");
                $deleteStmt->execute([':reference' => $reference]);
                
                error_log("[VT_DELETION_REQUESTS] Virtual transaction $reference moved to corbeille and deleted from main table");
            } else {
                error_log("[VT_DELETION_REQUESTS] WARNING: Virtual transaction $reference not found in main table");
            }
        }
        
        $db->commit();
        
        error_log("[VT_DELETION_REQUESTS] Request $reference successfully " . ($approve ? "approved" : "refused") . " by agent");
        
        echo json_encode([
            'success' => true,
            'message' => $approve ? "Demande approuvée et transaction supprimée" : "Demande refusée",
            'reference' => $reference,
            'statut' => $newStatus,
            'approved' => $approve
        ]);
        
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
    
} catch (PDOException $e) {
    error_log("[VT_DELETION_REQUESTS] DATABASE ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur base de données: ' . $e->getMessage(),
        'error_type' => 'PDOException'
    ]);
} catch (Exception $e) {
    error_log("[VT_DELETION_REQUESTS] GENERAL ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e)
    ]);
}
?>
