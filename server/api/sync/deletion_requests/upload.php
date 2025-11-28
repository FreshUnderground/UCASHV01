<?php
/**
 * API: Upload Deletion Requests (Admin creates deletion request)
 * Method: POST
 * Body: JSON array of deletion requests
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
    $database = new Database();
    $db = $database->getConnection();
    
    // Lire les données JSON
    $json = file_get_contents('php://input');
    $deletionRequests = json_decode($json, true);
    
    if (!is_array($deletionRequests)) {
        echo json_encode([
            'success' => false,
            'message' => 'Format de données invalide'
        ]);
        exit;
    }
    
    $uploaded = 0;
    $errors = [];
    
    foreach ($deletionRequests as $request) {
        try {
            // Vérifier si une demande existe déjà pour ce code_ops
            $checkStmt = $db->prepare("
                SELECT id FROM deletion_requests 
                WHERE code_ops = :code_ops
            ");
            $checkStmt->bindParam(':code_ops', $request['code_ops']);
            $checkStmt->execute();
            
            if ($checkStmt->rowCount() > 0) {
                // UPDATE si la demande existe déjà
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
                        validated_by_agent_id = :validated_by_agent_id,
                        validated_by_agent_name = :validated_by_agent_name,
                        validation_date = :validation_date,
                        statut = :statut,
                        last_modified_at = NOW(),
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE code_ops = :code_ops
                ");
            } else {
                // INSERT nouvelle demande
                $stmt = $db->prepare("
                    INSERT INTO deletion_requests (
                        code_ops, operation_id, operation_type, montant, devise,
                        destinataire, expediteur, client_nom,
                        requested_by_admin_id, requested_by_admin_name, request_date, reason,
                        validated_by_agent_id, validated_by_agent_name, validation_date,
                        statut, created_at, last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (
                        :code_ops, :operation_id, :operation_type, :montant, :devise,
                        :destinataire, :expediteur, :client_nom,
                        :requested_by_admin_id, :requested_by_admin_name, :request_date, :reason,
                        :validated_by_agent_id, :validated_by_agent_name, :validation_date,
                        :statut, NOW(), NOW(), :last_modified_by,
                        1, NOW()
                    )
                ");
            }
            
            // Convertir le statut enum index vers string MySQL
            $statuts = ['en_attente', 'validee', 'refusee', 'annulee'];
            $statut = isset($request['statut']) && isset($statuts[$request['statut']]) 
                ? $statuts[$request['statut']] 
                : 'en_attente';
            
            $stmt->bindParam(':code_ops', $request['code_ops']);
            $stmt->bindParam(':operation_id', $request['operation_id']);
            $stmt->bindParam(':operation_type', $request['operation_type']);
            $stmt->bindParam(':montant', $request['montant']);
            $stmt->bindParam(':devise', $request['devise']);
            $stmt->bindParam(':destinataire', $request['destinataire']);
            $stmt->bindParam(':expediteur', $request['expediteur']);
            $stmt->bindParam(':client_nom', $request['client_nom']);
            $stmt->bindParam(':requested_by_admin_id', $request['requested_by_admin_id']);
            $stmt->bindParam(':requested_by_admin_name', $request['requested_by_admin_name']);
            $stmt->bindParam(':request_date', $request['request_date']);
            $stmt->bindParam(':reason', $request['reason']);
            $stmt->bindParam(':validated_by_agent_id', $request['validated_by_agent_id']);
            $stmt->bindParam(':validated_by_agent_name', $request['validated_by_agent_name']);
            $stmt->bindParam(':validation_date', $request['validation_date']);
            $stmt->bindParam(':statut', $statut);
            $stmt->bindParam(':last_modified_by', $request['last_modified_by']);
            
            $stmt->execute();
            $uploaded++;
            
        } catch (PDOException $e) {
            $errors[] = [
                'code_ops' => $request['code_ops'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    echo json_encode([
        'success' => true,
        'uploaded' => $uploaded,
        'total' => count($deletionRequests),
        'errors' => $errors
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
?>
