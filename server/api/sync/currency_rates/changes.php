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

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    require_once '../../../config/database.php';
    
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    
    // Debug: Log input parameters
    error_log("Currency rates changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL
    $sql = "SELECT * FROM currency_rates WHERE is_active = 1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND updated_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY updated_at DESC";
    
    // Debug: Log SQL query
    error_log("Currency rates SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rates = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Debug: Log number of rates found
    error_log("Currency rates found: " . count($rates));
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($rates as $rate) {
        $entities[] = [
            'id' => (int)$rate['id'],
            'from_currency' => $rate['from_currency'],
            'to_currency' => $rate['to_currency'],
            'rate' => (float)$rate['rate'],
            'created_at' => $rate['created_at'],
            'updated_at' => $rate['updated_at'],
            'updated_by' => $rate['updated_by'],
            'is_active' => (bool)$rate['is_active']
        ];
    }
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    // Debug: Log response
    error_log("Currency rates response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Currency rates error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
