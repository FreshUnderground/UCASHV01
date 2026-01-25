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
    error_log("Shops changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL avec les bons noms de colonnes
    $sql = "SELECT * FROM shops WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at DESC";
    
    // Debug: Log SQL query
    error_log("Shops SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Debug: Log number of shops found
    error_log("Shops found: " . count($shops));
    
    // Convertir les données pour Flutter avec les bons noms de champs
    $entities = [];
    foreach ($shops as $shop) {
        $entities[] = [
            'id' => (int)$shop['id'],
            'designation' => $shop['designation'],
            'localisation' => $shop['localisation'],
            'is_principal' => (int)($shop['is_principal'] ?? 0),
            'is_transfer_shop' => (int)($shop['is_transfer_shop'] ?? 0),
            'devise_principale' => $shop['devise_principale'] ?? 'USD',
            'devise_secondaire' => $shop['devise_secondaire'] ?? null,
            'capital_initial' => (float)$shop['capital_initial'],
            'capital_actuel' => (float)$shop['capital_actuel'],
            'capital_cash' => (float)$shop['capital_cash'],
            'capital_airtel_money' => (float)$shop['capital_airtel_money'],
            'capital_mpesa' => (float)$shop['capital_mpesa'],
            'capital_orange_money' => (float)$shop['capital_orange_money'],
            'capital_initial_devise2' => isset($shop['capital_initial_devise2']) && $shop['capital_initial_devise2'] ? (float)$shop['capital_initial_devise2'] : null,
            'capital_actuel_devise2' => isset($shop['capital_actuel_devise2']) && $shop['capital_actuel_devise2'] ? (float)$shop['capital_actuel_devise2'] : null,
            'capital_cash_devise2' => isset($shop['capital_cash_devise2']) && $shop['capital_cash_devise2'] ? (float)$shop['capital_cash_devise2'] : null,
            'capital_airtel_money_devise2' => isset($shop['capital_airtel_money_devise2']) && $shop['capital_airtel_money_devise2'] ? (float)$shop['capital_airtel_money_devise2'] : null,
            'capital_mpesa_devise2' => isset($shop['capital_mpesa_devise2']) && $shop['capital_mpesa_devise2'] ? (float)$shop['capital_mpesa_devise2'] : null,
            'capital_orange_money_devise2' => isset($shop['capital_orange_money_devise2']) && $shop['capital_orange_money_devise2'] ? (float)$shop['capital_orange_money_devise2'] : null,
            'creances' => (float)($shop['creances'] ?? 0),
            'dettes' => (float)($shop['dettes'] ?? 0),
            'last_modified_at' => $shop['last_modified_at'],
            'last_modified_by' => $shop['last_modified_by'],
            'created_at' => $shop['created_at'],
            'is_synced' => (bool)$shop['is_synced'],
            'synced_at' => $shop['synced_at']
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
    error_log("Shops response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Shops error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>