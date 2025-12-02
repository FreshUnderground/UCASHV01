<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les paramètres de requête
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    // Construire la requête
    $sql = "
        SELECT 
            dc.id, 
            dc.shop_id, 
            dc.sim_numero, 
            dc.montant, 
            dc.telephone_client, 
            dc.date_depot, 
            dc.user_id,
            dc.is_synced, 
            dc.synced_at,
            dc.created_at,
            dc.updated_at,
            s.designation as shop_name
        FROM depot_clients dc
        LEFT JOIN shops s ON dc.shop_id = s.id
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND dc.updated_at > :since";
        $params[':since'] = $since;
    }
    
    // Ordonner par date de modification (les plus récents en premier)
    $sql .= " ORDER BY dc.updated_at DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $depots = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedDepots = [];
    foreach ($depots as $depot) {
        $formattedDepots[] = [
            'id' => (int)$depot['id'],
            'shop_id' => (int)$depot['shop_id'],
            'sim_numero' => $depot['sim_numero'],
            'montant' => (float)$depot['montant'],
            'telephone_client' => $depot['telephone_client'],
            'date_depot' => $depot['date_depot'],
            'user_id' => (int)$depot['user_id'],
            'is_synced' => (int)$depot['is_synced'],
            'synced_at' => $depot['synced_at'],
            'created_at' => $depot['created_at'],
            'updated_at' => $depot['updated_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Dépôts clients récupérés avec succès',
        'entities' => $formattedDepots,
        'count' => count($formattedDepots),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'entities' => [],
        'count' => 0,
        'timestamp' => date('c')
    ]);
}
?>
