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
    
    // Construire la requête avec JOIN pour récupérer shop_designation
    $sql = "
        SELECT 
            a.id, a.username, a.password, a.nom, a.shop_id, a.role, a.is_active,
            a.last_modified_at, a.last_modified_by, a.created_at,
            a.is_synced, a.synced_at,
            s.designation AS shop_designation
        FROM agents a
        LEFT JOIN shops s ON a.shop_id = s.id
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification (préfixer avec a. pour éviter ambiguïté)
    if ($since && !empty($since)) {
        $sql .= " AND a.last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // Ordonner par date de modification (les plus récents en premier)
    $sql .= " ORDER BY a.last_modified_at DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $agents = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedAgents = [];
    foreach ($agents as $agent) {
        $formattedAgents[] = [
            'id' => (int)$agent['id'],
            'username' => $agent['username'],
            'password' => $agent['password'],
            'nom' => $agent['nom'],
            'shop_id' => (int)$agent['shop_id'],
            'shop_designation' => $agent['shop_designation'], // ✅ Ajout du nom du shop
            'role' => $agent['role'],
            'is_active' => (bool)$agent['is_active'],
            'last_modified_at' => $agent['last_modified_at'],
            'last_modified_by' => $agent['last_modified_by'],
            'created_at' => $agent['created_at'],
            'is_synced' => (bool)$agent['is_synced'],
            'synced_at' => $agent['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Agents récupérés avec succès',
        'entities' => $formattedAgents,
        'count' => count($formattedAgents),
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