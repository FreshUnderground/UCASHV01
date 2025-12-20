<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once '../../../config/database.php';

try {
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    $shopId = $_GET['shop_id'] ?? null;
    
    // Construire la requête SQL
    $sql = "SELECT * FROM triangular_debt_settlements WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    // Filtrer par shop (soit débiteur, soit intermédiaire, soit créancier)
    if ($shopId) {
        $sql .= " AND (shop_debtor_id = ? OR shop_intermediary_id = ? OR shop_creditor_id = ?)";
        $params[] = $shopId;
        $params[] = $shopId;
        $params[] = $shopId;
    }
    
    $sql .= " ORDER BY date_reglement DESC, last_modified_at DESC";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $settlements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($settlements as $settlement) {
        $entities[] = [
            'id' => (int)$settlement['id'],
            'reference' => $settlement['reference'],
            'shopDebtorId' => (int)$settlement['shop_debtor_id'],
            'shopDebtorDesignation' => $settlement['shop_debtor_designation'],
            'shopIntermediaryId' => (int)$settlement['shop_intermediary_id'],
            'shopIntermediaryDesignation' => $settlement['shop_intermediary_designation'],
            'shopCreditorId' => (int)$settlement['shop_creditor_id'],
            'shopCreditorDesignation' => $settlement['shop_creditor_designation'],
            'montant' => (float)$settlement['montant'],
            'devise' => $settlement['devise'],
            'dateReglement' => $settlement['date_reglement'],
            'modePaiement' => $settlement['mode_paiement'],
            'notes' => $settlement['notes'],
            'agentId' => (int)$settlement['agent_id'],
            'agentUsername' => $settlement['agent_username'],
            'createdAt' => $settlement['created_at'],
            'lastModifiedAt' => $settlement['last_modified_at'],
            'lastModifiedBy' => $settlement['last_modified_by'],
            'isSynced' => (bool)$settlement['is_synced'],
            'syncedAt' => $settlement['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
