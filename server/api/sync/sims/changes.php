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
    error_log("SIMs changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL
    $sql = "SELECT * FROM sims WHERE 1=1";
    $params = [];

    // Debug: Log SQL query
    error_log("SIMs SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $simsData = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Debug: Log number found
    error_log("SIMs found: " . count($simsData));
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($simsData as $sim) {
        $entities[] = [
            'id' => (int)$sim['id'],
            'numero' => $sim['numero'],
            'operateur' => $sim['operateur'],
            'shop_id' => (int)$sim['shop_id'],
            'shop_designation' => $sim['shop_designation'] ?? null,
            'solde_initial' => (float)($sim['solde_initial'] ?? 0),
            'solde_actuel' => (float)($sim['solde_actuel'] ?? 0),
            // NOUVEAU: Support double devise
            'solde_initial_cdf' => (float)($sim['solde_initial_cdf'] ?? 0),
            'solde_actuel_cdf' => (float)($sim['solde_actuel_cdf'] ?? 0),
            'solde_initial_usd' => (float)($sim['solde_initial_usd'] ?? 0),
            'solde_actuel_usd' => (float)($sim['solde_actuel_usd'] ?? 0),
            'statut' => $sim['statut'] ?? 'active',
            'motif_suspension' => $sim['motif_suspension'] ?? null,
            'date_creation' => $sim['date_creation'],
            'date_suspension' => $sim['date_suspension'] ?? null,
            'cree_par' => $sim['cree_par'] ?? null,
            'last_modified_at' => $sim['last_modified_at'],
            'last_modified_by' => $sim['last_modified_by'] ?? null,
            'is_synced' => (bool)($sim['is_synced'] ?? false),
            'synced_at' => $sim['synced_at'] ?? null
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
    error_log("SIMs response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("SIMs error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>