<?php
/**
 * Endpoint pour télécharger les snapshots de dettes intershop
 * Télécharge les snapshots pré-calculés pour éviter le recalcul complet
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Méthode non autorisée. Utilisez GET.',
        'entities' => [],
        'count' => 0
    ]);
    exit();
}

// Vérifier que le fichier de config existe
if (!file_exists(__DIR__ . '/../../../config/database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier de configuration database.php introuvable',
        'entities' => [],
        'count' => 0
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';

try {
    error_log("[DAILY_DEBT_SNAPSHOTS] Download request received");
    
    // Récupérer les paramètres de requête
    $userId = $_GET['user_id'] ?? 'unknown';
    $userRole = $_GET['user_role'] ?? 'agent';
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $startDate = $_GET['start_date'] ?? null; // Format: YYYY-MM-DD
    $endDate = $_GET['end_date'] ?? null; // Format: YYYY-MM-DD
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10000;
    $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
    
    error_log("[DAILY_DEBT_SNAPSHOTS] User: $userId, Role: $userRole, Shop: " . ($shopId ?? 'ALL'));
    error_log("[DAILY_DEBT_SNAPSHOTS] Date range: $startDate to $endDate");
    
    // Construire la requête SQL
    $sql = "
        SELECT 
            id, shop_id, other_shop_id, date,
            dette_anterieure, creances_du_jour, dettes_du_jour, solde_cumule,
            created_at, updated_at,
            synced, sync_version
        FROM daily_intershop_debt_snapshot
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par shop_id si spécifié
    if ($shopId !== null) {
        $sql .= " AND shop_id = :shop_id";
        $params[':shop_id'] = $shopId;
        error_log("[DAILY_DEBT_SNAPSHOTS] Filtrage par shop_id: $shopId");
    }
    
    // Filtre par date de début
    if ($startDate !== null) {
        $sql .= " AND date >= :start_date";
        $params[':start_date'] = $startDate;
    }
    
    // Filtre par date de fin
    if ($endDate !== null) {
        $sql .= " AND date <= :end_date";
        $params[':end_date'] = $endDate;
    }
    
    // Ordonner par date (les plus récents en premier)
    $sql .= " ORDER BY date DESC, shop_id ASC, other_shop_id ASC";
    
    // Limiter les résultats
    $sql .= " LIMIT :limit OFFSET :offset";
    
    // Compter le total avant pagination
    $countSql = preg_replace('/SELECT.*FROM/s', 'SELECT COUNT(*) as total FROM', $sql);
    $countSql = preg_replace('/ ORDER BY.*$/', '', $countSql);
    $countSql = preg_replace('/ LIMIT.*$/', '', $countSql);
    
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Exécuter la requête principale
    $stmt = $pdo->prepare($sql);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $snapshots = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[DAILY_DEBT_SNAPSHOTS] Snapshots trouvés: " . count($snapshots) . " / $totalCount total");
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedSnapshots = [];
    $totalCreances = 0;
    $totalDettes = 0;
    
    foreach ($snapshots as $s) {
        $formatted = [
            'id' => (int)$s['id'],
            'shop_id' => (int)$s['shop_id'],
            'other_shop_id' => (int)$s['other_shop_id'],
            'date' => $s['date'],
            'dette_anterieure' => (float)$s['dette_anterieure'],
            'creances_du_jour' => (float)$s['creances_du_jour'],
            'dettes_du_jour' => (float)$s['dettes_du_jour'],
            'solde_cumule' => (float)$s['solde_cumule'],
            'created_at' => $s['created_at'],
            'updated_at' => $s['updated_at'],
            'synced' => (bool)$s['synced'],
            'sync_version' => (int)$s['sync_version'],
        ];
        
        $formattedSnapshots[] = $formatted;
        
        // Calculer les totaux
        $totalCreances += (float)$s['creances_du_jour'];
        $totalDettes += (float)$s['dettes_du_jour'];
    }
    
    // Calculer les statistiques
    $statsSql = "
        SELECT 
            COUNT(*) as nombre_snapshots,
            COUNT(DISTINCT shop_id) as nombre_shops,
            COUNT(DISTINCT date) as nombre_jours,
            SUM(creances_du_jour) as total_creances,
            SUM(dettes_du_jour) as total_dettes
        FROM daily_intershop_debt_snapshot
        WHERE 1=1
    ";
    
    $statsParams = [];
    if ($shopId !== null) {
        $statsSql .= " AND shop_id = :shop_id";
        $statsParams[':shop_id'] = $shopId;
    }
    if ($startDate !== null) {
        $statsSql .= " AND date >= :start_date";
        $statsParams[':start_date'] = $startDate;
    }
    if ($endDate !== null) {
        $statsSql .= " AND date <= :end_date";
        $statsParams[':end_date'] = $endDate;
    }
    
    $statsStmt = $pdo->prepare($statsSql);
    foreach ($statsParams as $key => $value) {
        $statsStmt->bindValue($key, $value);
    }
    $statsStmt->execute();
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    
    $response = [
        'success' => true,
        'message' => 'Téléchargement des snapshots de dettes réussi',
        'entities' => $formattedSnapshots,
        'count' => count($formattedSnapshots),
        'total_count' => (int)$totalCount,
        'has_more' => ($offset + $limit) < $totalCount,
        'offset' => $offset,
        'limit' => $limit,
        'stats' => [
            'nombre_snapshots' => (int)$stats['nombre_snapshots'],
            'nombre_shops' => (int)$stats['nombre_shops'],
            'nombre_jours' => (int)$stats['nombre_jours'],
            'total_creances' => (float)$stats['total_creances'],
            'total_dettes' => (float)$stats['total_dettes'],
            'solde_net' => (float)$stats['total_creances'] - (float)$stats['total_dettes'],
        ],
        'filter' => [
            'shop_id' => $shopId,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'user_role' => $userRole,
        ],
        'timestamp' => date('c')
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("[DAILY_DEBT_SNAPSHOTS] Download error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'entities' => [],
        'count' => 0,
        'timestamp' => date('c')
    ], JSON_UNESCAPED_UNICODE);
}
?>
