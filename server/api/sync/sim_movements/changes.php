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
    error_log("SIM Movements changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL
    $sql = "SELECT * FROM sim_movements WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY date_movement DESC";
    
    // Debug: Log SQL query
    error_log("SIM Movements SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $movementsData = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Debug: Log number found
    error_log("SIM Movements found: " . count($movementsData));
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($movementsData as $mvt) {
        $entities[] = [
            'id' => (int)$mvt['id'],
            'sim_id' => (int)$mvt['sim_id'],
            'sim_numero' => $mvt['sim_numero'],
            'ancien_shop_id' => isset($mvt['ancien_shop_id']) ? (int)$mvt['ancien_shop_id'] : null,
            'ancien_shop_designation' => $mvt['ancien_shop_designation'] ?? null,
            'nouveau_shop_id' => (int)$mvt['nouveau_shop_id'],
            'nouveau_shop_designation' => $mvt['nouveau_shop_designation'],
            'admin_responsable' => $mvt['admin_responsable'],
            'motif' => $mvt['motif'] ?? null,
            'date_movement' => $mvt['date_movement'],
            'last_modified_at' => $mvt['last_modified_at'],
            'last_modified_by' => $mvt['last_modified_by'] ?? null,
            'is_synced' => (bool)($mvt['is_synced'] ?? false),
            'synced_at' => $mvt['synced_at'] ?? null
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
    error_log("SIM Movements response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("SIM Movements error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>