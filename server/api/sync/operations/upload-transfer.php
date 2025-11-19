<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    
    // Lire les données JSON
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (empty($data['code_ops'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Code opération requis'
        ]);
        exit;
    }
    
    $code_ops = $data['code_ops'];
    
    // Vérifier si l'opération existe déjà
    $check_query = "SELECT id FROM operations WHERE code_ops = :code_ops LIMIT 1";
    $check_stmt = $pdo->prepare($check_query);
    $check_stmt->bindParam(':code_ops', $code_ops);
    $check_stmt->execute();
    
    $exists = $check_stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($exists) {
        // Mettre à jour l'opération existante
        $update_query = "UPDATE operations SET
                         type = :type,
                         reference = :reference,
                         date_op = :date_op,
                         shop_id = :shop_id,
                         shop_source_id = :shop_source_id,
                         shop_destination_id = :shop_destination_id,
                         client_id = :client_id,
                         agent_id = :agent_id,
                         montant_brut = :montant_brut,
                         montant_net = :montant_net,
                         commission = :commission,
                         devise = :devise,
                         statut = :statut,
                         destinataire = :destinataire,
                         telephone_destinataire = :telephone_destinataire,
                         observation = :observation,
                         updated_at = NOW()
                         WHERE code_ops = :code_ops";
        
        $stmt = $pdo->prepare($update_query);
        $stmt->bindParam(':type', $data['type']);
        $stmt->bindParam(':reference', $data['reference']);
        $stmt->bindParam(':date_op', $data['date_op']);
        $stmt->bindParam(':shop_id', $data['shop_id'], PDO::PARAM_INT);
        $stmt->bindParam(':shop_source_id', $data['shop_source_id'], PDO::PARAM_INT);
        $stmt->bindParam(':shop_destination_id', $data['shop_destination_id'], PDO::PARAM_INT);
        $stmt->bindParam(':client_id', $data['client_id'], PDO::PARAM_INT);
        $stmt->bindParam(':agent_id', $data['agent_id'], PDO::PARAM_INT);
        $stmt->bindParam(':montant_brut', $data['montant_brut']);
        $stmt->bindParam(':montant_net', $data['montant_net']);
        $stmt->bindParam(':commission', $data['commission']);
        $stmt->bindParam(':devise', $data['devise']);
        $stmt->bindParam(':statut', $data['statut']);
        $stmt->bindParam(':destinataire', $data['destinataire']);
        $stmt->bindParam(':telephone_destinataire', $data['telephone_destinataire']);
        $stmt->bindParam(':observation', $data['observation']);
        $stmt->bindParam(':code_ops', $code_ops);
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Transfert mis à jour avec succès',
                'action' => 'updated',
                'code_ops' => $code_ops
            ]);
        } else {
            throw new Exception('Erreur lors de la mise à jour');
        }
        
    } else {
        // Insérer une nouvelle opération
        $insert_query = "INSERT INTO operations (
                         type, code_ops, reference, date_op,
                         shop_id, shop_source_id, shop_destination_id,
                         client_id, agent_id,
                         montant_brut, montant_net, commission, devise,
                         statut, destinataire, telephone_destinataire, observation,
                         created_at, updated_at
                         ) VALUES (
                         :type, :code_ops, :reference, :date_op,
                         :shop_id, :shop_source_id, :shop_destination_id,
                         :client_id, :agent_id,
                         :montant_brut, :montant_net, :commission, :devise,
                         :statut, :destinataire, :telephone_destinataire, :observation,
                         NOW(), NOW()
                         )";
        
        $stmt = $pdo->prepare($insert_query);
        $stmt->bindParam(':type', $data['type']);
        $stmt->bindParam(':code_ops', $code_ops);
        $stmt->bindParam(':reference', $data['reference']);
        $stmt->bindParam(':date_op', $data['date_op']);
        $stmt->bindParam(':shop_id', $data['shop_id'], PDO::PARAM_INT);
        $stmt->bindParam(':shop_source_id', $data['shop_source_id'], PDO::PARAM_INT);
        $stmt->bindParam(':shop_destination_id', $data['shop_destination_id'], PDO::PARAM_INT);
        $stmt->bindParam(':client_id', $data['client_id'], PDO::PARAM_INT);
        $stmt->bindParam(':agent_id', $data['agent_id'], PDO::PARAM_INT);
        $stmt->bindParam(':montant_brut', $data['montant_brut']);
        $stmt->bindParam(':montant_net', $data['montant_net']);
        $stmt->bindParam(':commission', $data['commission']);
        $stmt->bindParam(':devise', $data['devise']);
        $stmt->bindParam(':statut', $data['statut']);
        $stmt->bindParam(':destinataire', $data['destinataire']);
        $stmt->bindParam(':telephone_destinataire', $data['telephone_destinataire']);
        $stmt->bindParam(':observation', $data['observation']);
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true,
                'message' => 'Transfert créé avec succès',
                'action' => 'created',
                'code_ops' => $code_ops,
                'id' => $pdo->lastInsertId()
            ]);
        } else {
            throw new Exception('Erreur lors de la création');
        }
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
