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
    $sql = "SELECT * FROM audit_log WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND created_at > ?";
        $params[] = $since;
    }
    
    if ($shopId) {
        $sql .= " AND shop_id = ?";
        $params[] = $shopId;
    }
    
    $sql .= " ORDER BY created_at DESC LIMIT 500"; // Limiter pour performances
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $audits = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($audits as $audit) {
        $entities[] = [
            'id' => (int)$audit['id'],
            'table_name' => $audit['table_name'],
            'record_id' => (int)$audit['record_id'],
            'action' => $audit['action'],
            'old_values' => $audit['old_values'] ? json_decode($audit['old_values'], true) : null,
            'new_values' => $audit['new_values'] ? json_decode($audit['new_values'], true) : null,
            'changed_fields' => $audit['changed_fields'] ? json_decode($audit['changed_fields'], true) : null,
            'user_id' => $audit['user_id'] ? (int)$audit['user_id'] : null,
            'user_role' => $audit['user_role'],
            'username' => $audit['username'],
            'shop_id' => $audit['shop_id'] ? (int)$audit['shop_id'] : null,
            'ip_address' => $audit['ip_address'],
            'device_info' => $audit['device_info'],
            'reason' => $audit['reason'],
            'created_at' => $audit['created_at'],
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
