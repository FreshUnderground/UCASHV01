<?php
/**
 * API: Validate Deletion Request (Agent validates and deletes operation)
 * Method: POST
 * Body: {
 *   "code_ops": "...",
 *   "validated_by_agent_id": 123,
 *   "validated_by_agent_name": "...",
 *   "action": "approve" | "reject"
 * }
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
    
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!isset($data['code_ops']) || !isset($data['action'])) {
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres manquants'
        ]);
        exit;
    }
    
    $code_ops = $data['code_ops'];
    $action = $data['action']; // 'approve' or 'reject'
    $agent_id = $data['validated_by_agent_id'] ?? null;
    $agent_name = $data['validated_by_agent_name'] ?? 'agent';
    
    // Commencer une transaction
    $db->beginTransaction();
    
    try {
        // 1. Récupérer la demande de suppression
        $stmt = $db->prepare("
            SELECT * FROM deletion_requests 
            WHERE code_ops = :code_ops AND statut = 'en_attente'
        ");
        $stmt->bindParam(':code_ops', $code_ops);
        $stmt->execute();
        $request = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$request) {
            throw new Exception('Demande de suppression non trouvée ou déjà traitée');
        }
        
        if ($action === 'approve') {
            // 2. Récupérer l'opération complète
            $stmt = $db->prepare("
                SELECT * FROM operations WHERE code_ops = :code_ops
            ");
            $stmt->bindParam(':code_ops', $code_ops);
            $stmt->execute();
            $operation = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$operation) {
                throw new Exception('Opération non trouvée');
            }
            
            // 3. Copier l'opération dans la corbeille
            $stmt = $db->prepare("
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
                    deleted_by_admin_id, deleted_by_admin_name,
                    validated_by_agent_id, validated_by_agent_name,
                    deletion_request_id, deletion_reason,
                    deleted_at, is_synced, synced_at
                ) VALUES (
                    :original_id, :code_ops, :type,
                    :shop_source_id, :shop_source_designation,
                    :shop_destination_id, :shop_destination_designation,
                    :agent_id, :agent_username,
                    :client_id, :client_nom,
                    :montant_brut, :commission, :montant_net, :devise,
                    :mode_paiement, :destinataire, :telephone_destinataire,
                    :reference, :sim_numero, :statut, :notes, :observation,
                    :date_op, :date_validation,
                    :created_at_original, :last_modified_at_original, :last_modified_by_original,
                    :deleted_by_admin_id, :deleted_by_admin_name,
                    :validated_by_agent_id, :validated_by_agent_name,
                    :deletion_request_id, :deletion_reason,
                    NOW(), 1, NOW()
                )
            ");
            
            $stmt->bindParam(':original_id', $operation['id']);
            $stmt->bindParam(':code_ops', $operation['code_ops']);
            $stmt->bindParam(':type', $operation['type']);
            $stmt->bindParam(':shop_source_id', $operation['shop_source_id']);
            $stmt->bindParam(':shop_source_designation', $operation['shop_source_designation']);
            $stmt->bindParam(':shop_destination_id', $operation['shop_destination_id']);
            $stmt->bindParam(':shop_destination_designation', $operation['shop_destination_designation']);
            $stmt->bindParam(':agent_id', $operation['agent_id']);
            $stmt->bindParam(':agent_username', $operation['agent_username']);
            $stmt->bindParam(':client_id', $operation['client_id']);
            $stmt->bindParam(':client_nom', $operation['client_nom']);
            $stmt->bindParam(':montant_brut', $operation['montant_brut']);
            $stmt->bindParam(':commission', $operation['commission']);
            $stmt->bindParam(':montant_net', $operation['montant_net']);
            $stmt->bindParam(':devise', $operation['devise']);
            $stmt->bindParam(':mode_paiement', $operation['mode_paiement']);
            $stmt->bindParam(':destinataire', $operation['destinataire']);
            $stmt->bindParam(':telephone_destinataire', $operation['telephone_destinataire']);
            $stmt->bindParam(':reference', $operation['reference']);
            $stmt->bindParam(':sim_numero', $operation['sim_numero']);
            $stmt->bindParam(':statut', $operation['statut']);
            $stmt->bindParam(':notes', $operation['notes']);
            $stmt->bindParam(':observation', $operation['observation']);
            $stmt->bindParam(':date_op', $operation['date_op']);
            $stmt->bindParam(':date_validation', $operation['date_validation']);
            $stmt->bindParam(':created_at_original', $operation['created_at']);
            $stmt->bindParam(':last_modified_at_original', $operation['last_modified_at']);
            $stmt->bindParam(':last_modified_by_original', $operation['last_modified_by']);
            $stmt->bindParam(':deleted_by_admin_id', $request['requested_by_admin_id']);
            $stmt->bindParam(':deleted_by_admin_name', $request['requested_by_admin_name']);
            $stmt->bindParam(':validated_by_agent_id', $agent_id);
            $stmt->bindParam(':validated_by_agent_name', $agent_name);
            $stmt->bindParam(':deletion_request_id', $request['id']);
            $stmt->bindParam(':deletion_reason', $request['reason']);
            
            $stmt->execute();
            
            // 4. Supprimer l'opération de la table operations
            $stmt = $db->prepare("DELETE FROM operations WHERE code_ops = :code_ops");
            $stmt->bindParam(':code_ops', $code_ops);
            $stmt->execute();
            
            // 5. Mettre à jour la demande de suppression (validée)
            $stmt = $db->prepare("
                UPDATE deletion_requests SET
                    validated_by_agent_id = :agent_id,
                    validated_by_agent_name = :agent_name,
                    validation_date = NOW(),
                    statut = 'validee',
                    last_modified_at = NOW(),
                    is_synced = 1,
                    synced_at = NOW()
                WHERE code_ops = :code_ops
            ");
            $stmt->bindParam(':agent_id', $agent_id);
            $stmt->bindParam(':agent_name', $agent_name);
            $stmt->bindParam(':code_ops', $code_ops);
            $stmt->execute();
            
            $message = 'Opération supprimée avec succès et placée dans la corbeille';
            
        } else if ($action === 'reject') {
            // Refuser la demande de suppression
            $stmt = $db->prepare("
                UPDATE deletion_requests SET
                    validated_by_agent_id = :agent_id,
                    validated_by_agent_name = :agent_name,
                    validation_date = NOW(),
                    statut = 'refusee',
                    last_modified_at = NOW(),
                    is_synced = 1,
                    synced_at = NOW()
                WHERE code_ops = :code_ops
            ");
            $stmt->bindParam(':agent_id', $agent_id);
            $stmt->bindParam(':agent_name', $agent_name);
            $stmt->bindParam(':code_ops', $code_ops);
            $stmt->execute();
            
            $message = 'Demande de suppression refusée';
        } else {
            throw new Exception('Action invalide');
        }
        
        // Commit la transaction
        $db->commit();
        
        echo json_encode([
            'success' => true,
            'message' => $message
        ]);
        
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur: ' . $e->getMessage()
    ]);
}
?>
