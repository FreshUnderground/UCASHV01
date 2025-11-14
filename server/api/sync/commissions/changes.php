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
            id, type, taux, description, is_active,
            last_modified_at, last_modified_by, created_at,
            is_synced, synced_at
        FROM commissions
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // Ordonner par date de modification (les plus récents en premier)
    $sql .= " ORDER BY last_modified_at DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $commissions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedCommissions = [];
    foreach ($commissions as $c) {
        $formattedCommissions[] = [
            'id' => (int)$c['id'],
            'type' => $c['type'],
            'taux' => (float)$c['taux'],
            'description' => $c['description'],
            'isActive' => (bool)$c['is_active'],
            'lastModifiedAt' => $c['last_modified_at'],
            'lastModifiedBy' => $c['last_modified_by'],
            'createdAt' => $c['created_at'],
            'isSynced' => (bool)$c['is_synced'],
            'syncedAt' => $c['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Commissions récupérées avec succès',
        'entities' => $formattedCommissions,
        'count' => count($formattedCommissions),
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