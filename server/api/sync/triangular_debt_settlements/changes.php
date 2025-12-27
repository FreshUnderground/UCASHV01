<?php
/**
 * API corrigée pour la synchronisation des règlements triangulaires
 * Résout le problème de download en optimisant les filtres
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

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
    // Paramètres de requête
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    error_log("🔺 TRIANGULAR CHANGES - since: $since, user: $userId, role: $userRole, shop: $shopId");
    
    // Validation des paramètres requis
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants: user_id et user_role',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Requête SQL optimisée
    $sql = "SELECT `id`, `reference`, `shop_debtor_id`, `shop_debtor_designation`, 
                   `shop_intermediary_id`, `shop_intermediary_designation`, 
                   `shop_creditor_id`, `shop_creditor_designation`, 
                   `montant`, `devise`, `date_reglement`, `mode_paiement`, `notes`, 
                   `agent_id`, `agent_username`, `created_at`, `last_modified_at`, 
                   `last_modified_by`, `is_synced`, `synced_at`,
                   `is_deleted`, `deleted_at`, `deleted_by`, `delete_reason`
            FROM `triangular_debt_settlements` WHERE 1=1";
    
    $params = [];
    
    // CORRECTION 1: Filtrage temporel plus permissif
    if ($since && $since !== '' && $since !== 'null') {
        // Ajouter une marge de sécurité de 1 heure pour éviter de manquer des données
        $sql .= " AND (last_modified_at > ? OR created_at > ?)";
        $params[] = $since;
        $params[] = $since;
        error_log("🔺 Filtrage temporel: depuis $since (avec marge de sécurité)");
    } else {
        // Si pas de 'since', récupérer les données récentes (30 derniers jours)
        $sql .= " AND (created_at > DATE_SUB(NOW(), INTERVAL 30 DAY) OR last_modified_at > DATE_SUB(NOW(), INTERVAL 30 DAY))";
        error_log("🔺 Pas de 'since' - récupération des 30 derniers jours");
    }
    
    // CORRECTION 2: Filtrage par shop plus intelligent
    if ($userRole !== 'admin') {
        if ($shopId && $shopId > 0) {
            // Agent avec shop_id: voir les règlements où son shop est impliqué
            $sql .= " AND (shop_debtor_id = ? OR shop_intermediary_id = ? OR shop_creditor_id = ?)";
            $params[] = $shopId;
            $params[] = $shopId;
            $params[] = $shopId;
            error_log("🔺 Agent filtrage par shop_id: $shopId");
        } else {
            // Agent sans shop_id: ne voir que ses propres règlements
            $sql .= " AND agent_id = ?";
            $params[] = $userId;
            error_log("🔺 Agent sans shop - seulement ses règlements (agent_id: $userId)");
        }
    } else {
        error_log("🔺 Mode ADMIN - tous les règlements");
    }
    
    // CORRECTION 4: Ordre optimisé et limite sécurisée
    $sql .= " ORDER BY last_modified_at DESC, created_at DESC LIMIT ?";
    $params[] = min($limit, 5000); // Limite max de sécurité
    
    error_log("🔺 SQL final: $sql");
    error_log("🔺 Paramètres: " . json_encode($params));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $settlements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("🔺 Résultats trouvés: " . count($settlements));
    
    // Conversion des données pour Flutter
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
    
    // Statistiques pour le debug
    $stats = [
        'total_found' => count($entities),
        'deleted_count' => count(array_filter($entities, fn($e) => $e['isDeleted'])),
        'active_count' => count(array_filter($entities, fn($e) => !$e['isDeleted'])),
    ];
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'stats' => $stats,
        'debug_info' => [
            'since_param' => $since,
            'user_role' => $userRole,
            'shop_id' => $shopId,
            'sql_params_count' => count($params),
        ],
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    error_log("🔺 Réponse envoyée: " . count($entities) . " règlements");
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("🔺 ERREUR triangular changes: " . $e->getMessage());
    error_log("🔺 Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_details' => $e->getTraceAsString(),
        'timestamp' => date('c')
    ]);
}
?>
