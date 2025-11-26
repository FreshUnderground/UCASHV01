<?php
/**
 * API: Lister les réconciliations
 * GET /api/reconciliation/list.php
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

require_once __DIR__ . '/../../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

try {
    $shopId = $_GET['shop_id'] ?? null;
    $startDate = $_GET['start_date'] ?? null;
    $endDate = $_GET['end_date'] ?? null;
    $statut = $_GET['statut'] ?? null;
    $withGaps = isset($_GET['with_gaps']) && $_GET['with_gaps'] === 'true';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;

    // Construction de la requête
    $sql = "SELECT r.*, s.designation as shop_name 
            FROM reconciliations r
            LEFT JOIN shops s ON r.shop_id = s.id
            WHERE 1=1";
    $params = [];

    if ($shopId) {
        $sql .= " AND r.shop_id = :shop_id";
        $params[':shop_id'] = $shopId;
    }

    if ($startDate) {
        $sql .= " AND r.date_reconciliation >= :start_date";
        $params[':start_date'] = $startDate;
    }

    if ($endDate) {
        $sql .= " AND r.date_reconciliation <= :end_date";
        $params[':end_date'] = $endDate;
    }

    if ($statut) {
        $sql .= " AND r.statut = :statut";
        $params[':statut'] = strtoupper($statut);
    }

    if ($withGaps) {
        $sql .= " AND ABS(r.ecart_pourcentage) > 0";
    }

    $sql .= " ORDER BY r.date_reconciliation DESC, r.created_at DESC LIMIT :limit OFFSET :offset";

    $stmt = $pdo->prepare($sql);

    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);

    $stmt->execute();
    $reconciliations = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Compter le total
    $countSql = str_replace('SELECT r.*, s.designation as shop_name', 'SELECT COUNT(*) as total', $sql);
    $countSql = preg_replace('/ORDER BY .* LIMIT .* OFFSET .*/', '', $countSql);
    $countStmt = $pdo->prepare($countSql);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];

    // Calculer les statistiques
    $stats = [
        'total_reconciliations' => $total,
        'with_gaps' => 0,
        'action_required' => 0,
        'avg_ecart_pourcentage' => 0,
    ];

    if (!empty($reconciliations)) {
        $totalEcart = 0;
        foreach ($reconciliations as $reconciliation) {
            if (abs($reconciliation['ecart_pourcentage']) > 0) {
                $stats['with_gaps']++;
                $totalEcart += abs($reconciliation['ecart_pourcentage']);
            }
            if ($reconciliation['action_corrective_requise']) {
                $stats['action_required']++;
            }
        }
        if ($stats['with_gaps'] > 0) {
            $stats['avg_ecart_pourcentage'] = round($totalEcart / $stats['with_gaps'], 2);
        }
    }

    echo json_encode([
        'success' => true,
        'reconciliations' => $reconciliations,
        'total' => $total,
        'limit' => $limit,
        'offset' => $offset,
        'stats' => $stats,
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
