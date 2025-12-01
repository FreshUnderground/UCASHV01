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
    error_log("Virtual Transactions changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL avec les bons noms de colonnes
    $sql = "SELECT * FROM virtual_transactions WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at DESC";
    
    // Debug: Log SQL query
    error_log("Virtual Transactions SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Debug: Log number of transactions found
    error_log("Virtual Transactions found: " . count($transactions));
    
    // Convertir les données pour Flutter avec les bons types
    $entities = [];
    foreach ($transactions as $vt) {
        $entities[] = [
            'id' => (int)$vt['id'],
            'reference' => $vt['reference'],
            'montant_virtuel' => (float)$vt['montant_virtuel'],
            'frais' => (float)($vt['frais'] ?? 0),
            'montant_cash' => (float)$vt['montant_cash'],
            'devise' => $vt['devise'] ?? 'USD',
            'sim_numero' => $vt['sim_numero'],
            'shop_id' => (int)$vt['shop_id'],
            'shop_designation' => $vt['shop_designation'] ?? null,
            'agent_id' => (int)$vt['agent_id'],
            'agent_username' => $vt['agent_username'] ?? null,
            'client_nom' => $vt['client_nom'] ?? null,
            'client_telephone' => $vt['client_telephone'] ?? null,
            'statut' => $vt['statut'] ?? 'enAttente',
            'date_enregistrement' => $vt['date_enregistrement'],
            'date_validation' => $vt['date_validation'] ?? null,
            'notes' => $vt['notes'] ?? null,
            'last_modified_at' => $vt['last_modified_at'],
            'last_modified_by' => $vt['last_modified_by'],
            'is_synced' => (bool)$vt['is_synced'],
            'synced_at' => $vt['synced_at']
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
    error_log("Virtual Transactions response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Virtual Transactions error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>