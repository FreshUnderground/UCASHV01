<?php
/**
 * API: Upload Virtual Transaction Deletion Requests
 * Method: POST
 * Body: JSON array of virtual transaction deletion requests
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    $input = file_get_contents('php://input');
    error_log("[VT_DELETION_REQUESTS] Upload - Raw input: " . substr($input, 0, 1000));
    
    $data = json_decode($input, true);
    
    if (!$data || !is_array($data)) {
        throw new Exception('Données JSON invalides');
    }
    
    $uploaded = 0;
    $errors = [];
    
    foreach ($data as $index => $request) {
        try {
            error_log("[VT_DELETION_REQUESTS] Processing request $index: " . json_encode($request));
            
            // Validation des champs requis
            if (empty($request['reference'])) {
                throw new Exception('Référence manquante pour la demande ' . $index);
            }
            
            if (empty($request['transaction_type'])) {
                throw new Exception('Type de transaction manquant pour la demande ' . $index);
            }
            
            if (!isset($request['montant']) || $request['montant'] <= 0) {
                throw new Exception('Montant invalide pour la demande ' . $index);
            }
            
            if (empty($request['requested_by_admin_id'])) {
                throw new Exception('ID admin demandeur manquant pour la demande ' . $index);
            }
            
            // Check if request already exists
            $checkStmt = $pdo->prepare("SELECT id FROM virtual_transaction_deletion_requests WHERE reference = ?");
            $checkStmt->execute([$request['reference']]);
            
            if ($checkStmt->fetch()) {
                // Update existing request
                $stmt = $pdo->prepare("
                    UPDATE virtual_transaction_deletion_requests SET
                        virtual_transaction_id = ?,
                        transaction_type = ?,
                        montant = ?,
                        devise = ?,
                        destinataire = ?,
                        expediteur = ?,
                        client_nom = ?,
                        requested_by_admin_id = ?,
                        requested_by_admin_name = ?,
                        request_date = ?,
                        reason = ?,
                        validated_by_admin_id = ?,
                        validated_by_admin_name = ?,
                        validation_admin_date = ?,
                        validated_by_agent_id = ?,
                        validated_by_agent_name = ?,
                        validation_date = ?,
                        statut = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = TRUE,
                        synced_at = NOW()
                    WHERE reference = ?
                ");
                
                $stmt->execute([
                    $request['virtual_transaction_id'] ?? null,
                    $request['transaction_type'],
                    $request['montant'],
                    $request['devise'] ?? 'USD',
                    $request['destinataire'] ?? null,
                    $request['expediteur'] ?? null,
                    $request['client_nom'] ?? null,
                    $request['requested_by_admin_id'],
                    $request['requested_by_admin_name'],
                    $request['request_date'],
                    $request['reason'] ?? null,
                    $request['validated_by_admin_id'] ?? null,
                    $request['validated_by_admin_name'] ?? null,
                    $request['validation_admin_date'] ?? null,
                    $request['validated_by_agent_id'] ?? null,
                    $request['validated_by_agent_name'] ?? null,
                    $request['validation_date'] ?? null,
                    $request['statut'] ?? 'en_attente',
                    $request['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $request['last_modified_by'] ?? 'system',
                    $request['reference']
                ]);
            } else {
                // Insert new request
                $stmt = $pdo->prepare("
                    INSERT INTO virtual_transaction_deletion_requests (
                        reference, virtual_transaction_id, transaction_type, montant, devise,
                        destinataire, expediteur, client_nom,
                        requested_by_admin_id, requested_by_admin_name, request_date, reason,
                        validated_by_admin_id, validated_by_admin_name, validation_admin_date,
                        validated_by_agent_id, validated_by_agent_name, validation_date,
                        statut, last_modified_at, last_modified_by, is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE, NOW())
                ");
                
                $stmt->execute([
                    $request['reference'],
                    $request['virtual_transaction_id'] ?? null,
                    $request['transaction_type'],
                    $request['montant'],
                    $request['devise'] ?? 'USD',
                    $request['destinataire'] ?? null,
                    $request['expediteur'] ?? null,
                    $request['client_nom'] ?? null,
                    $request['requested_by_admin_id'],
                    $request['requested_by_admin_name'],
                    $request['request_date'],
                    $request['reason'] ?? null,
                    $request['validated_by_admin_id'] ?? null,
                    $request['validated_by_admin_name'] ?? null,
                    $request['validation_admin_date'] ?? null,
                    $request['validated_by_agent_id'] ?? null,
                    $request['validated_by_agent_name'] ?? null,
                    $request['validation_date'] ?? null,
                    $request['statut'] ?? 'en_attente',
                    $request['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $request['last_modified_by'] ?? 'system'
                ]);
            }
            
            $uploaded++;
            
        } catch (Exception $e) {
            $errors[] = [
                'request_reference' => $request['reference'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
            error_log("[VT_DELETION_REQUESTS] Error processing request: " . $e->getMessage());
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload terminé',
        'uploaded' => $uploaded,
        'total' => count($data),
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("[VT_DELETION_REQUESTS] Upload error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
