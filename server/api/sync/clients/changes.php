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
            c.id, c.nom, c.telephone, c.adresse, c.solde, 
            c.shop_id, c.shop_designation, 
            c.agent_id, c.agent_username, 
            c.role,
            c.last_modified_at, c.last_modified_by, c.created_at,
            c.is_synced, c.synced_at,
            s.designation as shop_name,
            a.username as agent_name
        FROM clients c
        LEFT JOIN shops s ON c.shop_id = s.id
        LEFT JOIN agents a ON c.agent_id = a.id
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND c.last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // Ordonner par date de modification (les plus récents en premier)
    $sql .= " ORDER BY c.last_modified_at DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $clients = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedClients = [];
    foreach ($clients as $client) {
        $formattedClients[] = [
            'id' => (int)$client['id'],
            'nom' => $client['nom'],
            'telephone' => $client['telephone'],
            'adresse' => $client['adresse'],
            'solde' => (float)$client['solde'],
            'shop_id' => (int)$client['shop_id'],
            'shop_designation' => $client['shop_designation'] ?? $client['shop_name'],
            'agent_id' => $client['agent_id'] ? (int)$client['agent_id'] : null,
            'agent_username' => $client['agent_username'] ?? $client['agent_name'],
            'role' => $client['role'],
            'lastModifiedAt' => $client['last_modified_at'],
            'lastModifiedBy' => $client['last_modified_by'],
            'createdAt' => $client['created_at'],
            'isSynced' => (bool)$client['is_synced'],
            'syncedAt' => $client['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Clients récupérés avec succès',
        'entities' => $formattedClients,
        'count' => count($formattedClients),
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