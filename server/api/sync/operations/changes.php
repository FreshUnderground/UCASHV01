<?php
// En-têtes CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With');
header('Content-Type: application/json');

// Gérer OPTIONS
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
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    error_log("📊 Requête changes.php: since=$since, user_id=$userId, user_role=$userRole, shop_id=$shopId");
    
    // Validation des paramètres requis
    if (!$userId || !$userRole) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Paramètres requis manquants: user_id et user_role sont obligatoires',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Construire la requête pour les opérations (Structure réelle de la table)
    $sql = "SELECT 
            o.id, o.type, o.montant_brut, o.montant_net, o.commission, o.devise, 
            o.code_ops, o.client_id, o.client_nom,
            o.agent_id, o.agent_username,
            o.shop_source_id, o.shop_source_designation,
            o.shop_destination_id, o.shop_destination_designation,
            o.destinataire, o.telephone_destinataire, o.reference,
            o.mode_paiement, o.statut, o.notes,
            o.created_at, o.last_modified_at, o.last_modified_by,
            o.is_synced, o.synced_at
        FROM operations o
        WHERE 1=1
    ";
    
    $params = [];
    
    // Filtre par date de modification
    if ($since && !empty($since)) {
        $sql .= " AND o.last_modified_at > :since";
        $params[':since'] = $since;
    }
    
    // LOGIQUE DE FILTRAGE:
    // - ADMIN: Télécharge TOUTES les opérations (aucun filtre)
    // - AGENT: Télécharge les opérations où:
    //          1. shop_source_id = son shop (opérations créées dans son shop)
    //          2. shop_destination_id = son shop ET type = transfert (pour validation)
    if ($userRole !== 'admin' && $shopId) {
        $sql .= " AND (";
        $sql .= "o.shop_source_id = :shopId";
        $sql .= " OR (o.shop_destination_id = :shopId2 AND o.type IN ('transfert_national', 'transfert_international_entrant'))";
        $sql .= ")";
        $params[':shopId'] = $shopId;
        $params[':shopId2'] = $shopId;
        error_log("🏪 Filtre AGENT: shopId = $shopId (role: $userRole)");
        error_log("   ✅ Télécharge: Opérations créées (shop_source_id) + Transferts à valider (shop_destination_id)");
    } else if ($userRole === 'admin') {
        error_log("👑 Admin: accès à TOUTES les opérations (tous shops)");
    } else if ($userRole !== 'admin' && !$shopId) {
        // Agents sans shop_id ne doivent PAS avoir accès aux opérations
        error_log("🔒 AGENT sans shop_id: accès REFUSÉ (aucune opération retournée)");
        http_response_code(403);
        echo json_encode([
            'success' => false,
            'message' => 'Accès refusé: Agent sans shop_id affecté',
            'entities' => [],
            'count' => 0,
            'timestamp' => date('c')
        ]);
        exit();
    } else {
        error_log("⚠️ AGENT sans shop_id: accès à toutes les opérations (risque!");
    }
    
    // Ordonner par date de modification (les plus récents en premier)
    $sql .= " ORDER BY o.last_modified_at DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT :limit";
    
    $stmt = $pdo->prepare($sql);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("📊 " . count($operations) . " opérations récupérées");
    
    // Formater les résultats pour correspondre au modèle Flutter
    $formattedOperations = [];
    foreach ($operations as $op) {
        $formattedOperations[] = [
            'id' => (int)$op['id'],
            'type' => $op['type'],
            'montant_brut' => (float)$op['montant_brut'],
            'montant_net' => (float)$op['montant_net'],
            'commission' => (float)$op['commission'],
            'devise' => $op['devise'],
            'code_ops' => $op['code_ops'],
            'client_id' => $op['client_id'] ? (int)$op['client_id'] : null,
            'client_nom' => $op['client_nom'],
            'agent_id' => $op['agent_id'] ? (int)$op['agent_id'] : null,
            'agent_username' => $op['agent_username'],
            'shop_source_id' => $op['shop_source_id'] ? (int)$op['shop_source_id'] : null,
            'shop_source_designation' => $op['shop_source_designation'],
            'shop_destination_id' => $op['shop_destination_id'] ? (int)$op['shop_destination_id'] : null,
            'shop_destination_designation' => $op['shop_destination_designation'],
            'destinataire' => $op['destinataire'],
            'telephone_destinataire' => $op['telephone_destinataire'],
            'reference' => $op['reference'],
            'mode_paiement' => $op['mode_paiement'],
            'statut' => $op['statut'],
            'notes' => $op['notes'],
            'date_op' => $op['created_at'], // Utiliser created_at comme date_op
            'created_at' => $op['created_at'],
            'last_modified_at' => $op['last_modified_at'],
            'last_modified_by' => $op['last_modified_by'],
            'is_synced' => (bool)$op['is_synced'],
            'synced_at' => $op['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'message' => 'Opérations récupérées avec succès',
        'entities' => $formattedOperations,
        'count' => count($formattedOperations),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("❌ Erreur changes.php: " . $e->getMessage());
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