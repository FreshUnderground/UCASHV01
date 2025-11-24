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
    $shopId = $_GET['shop_id'] ?? null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    // Construire la requête
    $sql = "
        SELECT 
            id, type, type_transaction, montant, description,
            shop_id, date_transaction, operation_id,
            agent_id, agent_username,
            created_at, last_modified_at, last_modified_by,
            is_synced, synced_at
        FROM comptes_speciaux
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // Filtre par shop (optionnel)
    if ($shopId !== null) {
        $sql .= " AND shop_id = :shop_id";
        $params[':shop_id'] = $shopId;
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
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedTransactions = [];
    foreach ($transactions as $t) {
        $formattedTransactions[] = [
            'id' => (int)$t['id'],
            'type' => $t['type'],
            'type_transaction' => $t['type_transaction'],
            'montant' => (float)$t['montant'],
            'description' => $t['description'],
            'shop_id' => $t['shop_id'] ? (int)$t['shop_id'] : null,
            'date_transaction' => $t['date_transaction'],
            'operation_id' => $t['operation_id'] ? (int)$t['operation_id'] : null,
            'agent_id' => $t['agent_id'] ? (int)$t['agent_id'] : null,
            'agent_username' => $t['agent_username'],
            'created_at' => $t['created_at'],
            'last_modified_at' => $t['last_modified_at'],
            'last_modified_by' => $t['last_modified_by'],
            'is_synced' => (bool)$t['is_synced'],
            'synced_at' => $t['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Comptes spéciaux récupérés avec succès',
        'entities' => $formattedTransactions,
        'count' => count($formattedTransactions),
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
