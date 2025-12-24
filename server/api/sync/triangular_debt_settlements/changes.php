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

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    // Récupérer les paramètres de requête (aligné sur les autres endpoints)
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    error_log("🔺 Requête triangular changes.php: since=$since, user_id=$userId, user_role=$userRole, shop_id=$shopId");
    
    // Validation des paramètres requis (aligné sur operations/changes.php)
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants: user_id et user_role sont obligatoires',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Construire la requête SQL avec colonnes explicites (inclut les champs de suppression)
    $sql = "SELECT `id`, `reference`, `shop_debtor_id`, `shop_debtor_designation`, 
                   `shop_intermediary_id`, `shop_intermediary_designation`, 
                   `shop_creditor_id`, `shop_creditor_designation`, 
                   `montant`, `devise`, `date_reglement`, `mode_paiement`, `notes`, 
                   `agent_id`, `agent_username`, `created_at`, `last_modified_at`, 
                   `last_modified_by`, `is_synced`, `synced_at`,
                   `is_deleted`, `deleted_at`, `deleted_by`, `delete_reason`
            FROM `triangular_debt_settlements` WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    // Filtrer par shop (soit débiteur, soit intermédiaire, soit créancier)
    if ($userRole !== 'admin' && $shopId) {
        $sql .= " AND (shop_debtor_id = ? OR shop_intermediary_id = ? OR shop_creditor_id = ?)";
        $params[] = $shopId;
        $params[] = $shopId;
        $params[] = $shopId;
        error_log("🔺 Filtrage triangular par shop_id: $shopId");
    } else {
        error_log("🔺 Mode ADMIN ou pas de shop_id: téléchargement de tous les règlements");
    }
    
    $sql .= " ORDER BY date_reglement DESC, last_modified_at DESC LIMIT ?";
    $params[] = $limit;
    
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
            'isDeleted' => (bool)($settlement['is_deleted'] ?? false),
            'deletedAt' => $settlement['deleted_at'],
            'deletedBy' => $settlement['deleted_by'],
            'deleteReason' => $settlement['delete_reason'],
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
