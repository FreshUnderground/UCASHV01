<?php
/**
 * API: Récupérer l'historique d'audit d'un enregistrement
 * GET /api/audit/get-history.php?table_name=operations&record_id=123
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
    $tableName = $_GET['table_name'] ?? null;
    $recordId = $_GET['record_id'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $shopId = $_GET['shop_id'] ?? null;
    $startDate = $_GET['start_date'] ?? null;
    $endDate = $_GET['end_date'] ?? null;
    $action = $_GET['action'] ?? null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;

    // Construction de la requête dynamique
    $sql = "SELECT * FROM audit_log WHERE 1=1";
    $params = [];

    if ($tableName) {
        $sql .= " AND table_name = :table_name";
        $params[':table_name'] = $tableName;
    }

    if ($recordId) {
        $sql .= " AND record_id = :record_id";
        $params[':record_id'] = $recordId;
    }

    if ($userId) {
        $sql .= " AND user_id = :user_id";
        $params[':user_id'] = $userId;
    }

    if ($shopId) {
        $sql .= " AND shop_id = :shop_id";
        $params[':shop_id'] = $shopId;
    }

    if ($action) {
        $sql .= " AND action = :action";
        $params[':action'] = strtoupper($action);
    }

    if ($startDate) {
        $sql .= " AND created_at >= :start_date";
        $params[':start_date'] = $startDate;
    }

    if ($endDate) {
        $sql .= " AND created_at <= :end_date";
        $params[':end_date'] = $endDate . ' 23:59:59';
    }

    $sql .= " ORDER BY created_at DESC LIMIT :limit OFFSET :offset";

    $stmt = $pdo->prepare($sql);

    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);

    $stmt->execute();
    $audits = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Décoder les JSON
    foreach ($audits as &$audit) {
        if ($audit['old_values']) {
            $audit['old_values'] = json_decode($audit['old_values'], true);
        }
        if ($audit['new_values']) {
            $audit['new_values'] = json_decode($audit['new_values'], true);
        }
        if ($audit['changed_fields']) {
            $audit['changed_fields'] = json_decode($audit['changed_fields'], true);
        }
    }

    // Compter le total
    $countSql = "SELECT COUNT(*) as total FROM audit_log WHERE 1=1";
    foreach ($params as $key => $value) {
        $countSql = str_replace('1=1', '1=1 AND ' . substr($key, 1) . ' = ' . $key, $countSql);
    }
    $countStmt = $pdo->prepare(str_replace('SELECT COUNT(*) as total FROM audit_log WHERE 1=1 AND', 'SELECT COUNT(*) as total FROM audit_log WHERE', str_replace('ORDER BY created_at DESC LIMIT :limit OFFSET :offset', '', $sql)));
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];

    echo json_encode([
        'success' => true,
        'audits' => $audits,
        'total' => $total,
        'limit' => $limit,
        'offset' => $offset,
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
