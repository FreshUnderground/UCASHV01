<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer le code_ops depuis les paramètres
    $code_ops = isset($_GET['code_ops']) ? $_GET['code_ops'] : '';
    
    if (empty($code_ops)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Code opération requis'
        ]);
        exit;
    }
    
    // Récupérer l'opération
    $query = "SELECT 
                o.id, o.type, o.montant_brut, o.montant_net, o.commission, o.devise,
                o.code_ops, o.client_id, o.client_nom,
                o.agent_id, o.agent_username,
                o.shop_source_id, o.shop_source_designation,
                o.shop_destination_id, o.shop_destination_designation,
                o.destinataire, o.telephone_destinataire, o.reference,
                o.mode_paiement, o.statut, o.notes,
                o.created_at, o.last_modified_at, o.last_modified_by,
                o.is_synced, o.synced_at
              FROM operations o
              WHERE o.code_ops = :code_ops
              LIMIT 1";
    
    $stmt = $pdo->prepare($query);
    $stmt->bindParam(':code_ops', $code_ops);
    $stmt->execute();
    
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$row) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Opération non trouvée'
        ]);
        exit;
    }
    
    $operation = [
        'id' => (int)$row['id'],
        'type' => $row['type'],
        'code_ops' => $row['code_ops'],
        'reference' => $row['reference'],
        'date_op' => $row['created_at'],
        'shop_id' => $row['shop_source_id'] ? (int)$row['shop_source_id'] : null,
        'shop_source_id' => $row['shop_source_id'] ? (int)$row['shop_source_id'] : null,
        'shop_destination_id' => $row['shop_destination_id'] ? (int)$row['shop_destination_id'] : null,
        'shop_source_designation' => $row['shop_source_designation'],
        'shop_destination_designation' => $row['shop_destination_designation'],
        'client_id' => $row['client_id'] ? (int)$row['client_id'] : null,
        'client_nom' => $row['client_nom'],
        'agent_id' => $row['agent_id'] ? (int)$row['agent_id'] : null,
        'agent_username' => $row['agent_username'],
        'montant_brut' => (float)$row['montant_brut'],
        'montant_net' => (float)$row['montant_net'],
        'commission' => (float)$row['commission'],
        'devise' => $row['devise'],
        'statut' => $row['statut'],
        'mode_paiement' => $row['mode_paiement'],
        'destinataire' => $row['destinataire'],
        'telephone_destinataire' => $row['telephone_destinataire'],
        'notes' => $row['notes'],
        'created_at' => $row['created_at'],
        'last_modified_at' => $row['last_modified_at'],
        'last_modified_by' => $row['last_modified_by'],
        'is_synced' => (bool)$row['is_synced'],
        'synced_at' => $row['synced_at'],
    ];
    
    echo json_encode([
        'success' => true,
        'data' => $operation,
        'message' => 'Statut récupéré avec succès'
    ]);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
