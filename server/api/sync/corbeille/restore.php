<?php
/**
 * API: Restore Operation from Trash
 * Method: POST
 * Body: {
 *   "code_ops": "...",
 *   "restored_by": "..."
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
    
    if (!isset($data['code_ops'])) {
        echo json_encode([
            'success' => false,
            'message' => 'Code opération manquant'
        ]);
        exit;
    }
    
    $code_ops = $data['code_ops'];
    $restored_by = $data['restored_by'] ?? 'admin';
    
    // Commencer une transaction
    $db->beginTransaction();
    
    try {
        // 1. Récupérer l'opération de la corbeille
        $stmt = $db->prepare("
            SELECT * FROM operations_corbeille 
            WHERE code_ops = :code_ops AND is_restored = 0
            ORDER BY deleted_at DESC
            LIMIT 1
        ");
        $stmt->bindParam(':code_ops', $code_ops);
        $stmt->execute();
        $corbeille = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$corbeille) {
            throw new Exception('Opération non trouvée dans la corbeille ou déjà restaurée');
        }
        
        // 2. Restaurer l'opération dans la table operations
        $stmt = $db->prepare("
            INSERT INTO operations (
                code_ops, type, shop_source_id, shop_source_designation,
                shop_destination_id, shop_destination_designation,
                agent_id, agent_username, client_id, client_nom,
                montant_brut, commission, montant_net, devise,
                mode_paiement, destinataire, telephone_destinataire,
                reference, sim_numero, statut, notes, observation,
                date_op, date_validation, created_at, last_modified_at, last_modified_by,
                is_synced
            ) VALUES (
                :code_ops, :type, :shop_source_id, :shop_source_designation,
                :shop_destination_id, :shop_destination_designation,
                :agent_id, :agent_username, :client_id, :client_nom,
                :montant_brut, :commission, :montant_net, :devise,
                :mode_paiement, :destinataire, :telephone_destinataire,
                :reference, :sim_numero, :statut, :notes, :observation,
                :date_op, :date_validation, :created_at_original, NOW(), :restored_by,
                1
            )
        ");
        
        $stmt->bindParam(':code_ops', $corbeille['code_ops']);
        $stmt->bindParam(':type', $corbeille['type']);
        $stmt->bindParam(':shop_source_id', $corbeille['shop_source_id']);
        $stmt->bindParam(':shop_source_designation', $corbeille['shop_source_designation']);
        $stmt->bindParam(':shop_destination_id', $corbeille['shop_destination_id']);
        $stmt->bindParam(':shop_destination_designation', $corbeille['shop_destination_designation']);
        $stmt->bindParam(':agent_id', $corbeille['agent_id']);
        $stmt->bindParam(':agent_username', $corbeille['agent_username']);
        $stmt->bindParam(':client_id', $corbeille['client_id']);
        $stmt->bindParam(':client_nom', $corbeille['client_nom']);
        $stmt->bindParam(':montant_brut', $corbeille['montant_brut']);
        $stmt->bindParam(':commission', $corbeille['commission']);
        $stmt->bindParam(':montant_net', $corbeille['montant_net']);
        $stmt->bindParam(':devise', $corbeille['devise']);
        $stmt->bindParam(':mode_paiement', $corbeille['mode_paiement']);
        $stmt->bindParam(':destinataire', $corbeille['destinataire']);
        $stmt->bindParam(':telephone_destinataire', $corbeille['telephone_destinataire']);
        $stmt->bindParam(':reference', $corbeille['reference']);
        $stmt->bindParam(':sim_numero', $corbeille['sim_numero']);
        $stmt->bindParam(':statut', $corbeille['statut']);
        $stmt->bindParam(':notes', $corbeille['notes']);
        $stmt->bindParam(':observation', $corbeille['observation']);
        $stmt->bindParam(':date_op', $corbeille['date_op']);
        $stmt->bindParam(':date_validation', $corbeille['date_validation']);
        $stmt->bindParam(':created_at_original', $corbeille['created_at_original']);
        $stmt->bindParam(':restored_by', $restored_by);
        
        $stmt->execute();
        $restored_operation_id = $db->lastInsertId();
        
        // 3. Marquer comme restauré dans la corbeille
        $stmt = $db->prepare("
            UPDATE operations_corbeille SET
                is_restored = 1,
                restored_at = NOW(),
                restored_by = :restored_by,
                restored_operation_id = :restored_operation_id,
                is_synced = 1,
                synced_at = NOW()
            WHERE id = :corbeille_id
        ");
        $stmt->bindParam(':restored_by', $restored_by);
        $stmt->bindParam(':restored_operation_id', $restored_operation_id);
        $stmt->bindParam(':corbeille_id', $corbeille['id']);
        $stmt->execute();
        
        // Commit la transaction
        $db->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Opération restaurée avec succès',
            'restored_operation_id' => $restored_operation_id
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
