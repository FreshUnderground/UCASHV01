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
require_once __DIR__ . '/../../../classes/Database.php';

try {
    // Récupérer les paramètres de requête
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? null;
    $userRole = $_GET['user_role'] ?? null;
    $shopId = isset($_GET['shop_id']) ? intval($_GET['shop_id']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 1000;
    
    error_log("📊 Requête multi_month_payments changes.php: since=$since, user_id=$userId, user_role=$userRole, shop_id=$shopId");
    
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
    
    // Connexion à la base de données
    $database = new Database();
    $pdo = $database->getConnection();
    
    if (!$pdo) {
        throw new Exception('Impossible de se connecter à la base de données');
    }
    
    // Construire la requête pour les paiements multi-mois
    $sql = "SELECT 
            mp.id, mp.reference, mp.service_type, mp.service_description, 
            mp.montant_mensuel, mp.nombre_mois, mp.montant_total, mp.devise,
            mp.bonus, mp.heures_supplementaires, mp.taux_horaire_supp, 
            mp.montant_heures_supp, mp.montant_final_avec_ajustements,
            mp.date_debut, mp.date_fin, mp.client_id, mp.client_nom, 
            mp.client_telephone, mp.numero_compte, mp.shop_id, mp.shop_designation,
            mp.agent_id, mp.agent_username, mp.destinataire, mp.telephone_destinataire,
            mp.notes, mp.statut, mp.date_creation, mp.date_validation,
            mp.last_modified_at, mp.last_modified_by, mp.is_synced, mp.synced_at
        FROM multi_month_payments mp
        WHERE 1=1";
    
    $params = [];
    
    // Filtrage par date de modification (synchronisation incrémentale)
    if ($since) {
        $sql .= " AND (mp.last_modified_at > ? OR mp.synced_at > ?)";
        $params[] = $since;
        $params[] = $since;
    }
    
    // Filtrage par shop pour les agents (les admins voient tout)
    if ($userRole !== 'ADMIN' && $shopId) {
        $sql .= " AND mp.shop_id = ?";
        $params[] = $shopId;
    }
    
    // Ordonner par date de modification pour la synchronisation
    $sql .= " ORDER BY mp.last_modified_at DESC, mp.id DESC";
    
    // Limiter le nombre de résultats
    $sql .= " LIMIT ?";
    $params[] = $limit;
    
    error_log("📊 SQL: $sql");
    error_log("📊 Params: " . json_encode($params));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $payments = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($payments as $payment) {
        // Convertir le statut MySQL vers index Flutter
        $statutIndex = 0; // enAttente par défaut
        switch ($payment['statut']) {
            case 'enAttente': $statutIndex = 0; break;
            case 'validee': $statutIndex = 1; break;
            case 'annulee': $statutIndex = 2; break;
        }
        
        $entity = [
            'id' => (int)$payment['id'],
            'reference' => $payment['reference'],
            'service_type' => $payment['service_type'],
            'service_description' => $payment['service_description'],
            'montant_mensuel' => (float)$payment['montant_mensuel'],
            'nombre_mois' => (int)$payment['nombre_mois'],
            'montant_total' => (float)$payment['montant_total'],
            'devise' => $payment['devise'],
            'bonus' => (float)($payment['bonus'] ?? 0),
            'heures_supplementaires' => (float)($payment['heures_supplementaires'] ?? 0),
            'taux_horaire_supp' => (float)($payment['taux_horaire_supp'] ?? 0),
            'montant_heures_supp' => (float)($payment['montant_heures_supp'] ?? 0),
            'montant_final_avec_ajustements' => (float)($payment['montant_final_avec_ajustements'] ?? 0),
            'date_debut' => $payment['date_debut'],
            'date_fin' => $payment['date_fin'],
            'client_id' => $payment['client_id'] ? (int)$payment['client_id'] : null,
            'client_nom' => $payment['client_nom'],
            'client_telephone' => $payment['client_telephone'],
            'numero_compte' => $payment['numero_compte'],
            'shop_id' => (int)$payment['shop_id'],
            'shop_designation' => $payment['shop_designation'],
            'agent_id' => (int)$payment['agent_id'],
            'agent_username' => $payment['agent_username'],
            'destinataire' => $payment['destinataire'],
            'telephone_destinataire' => $payment['telephone_destinataire'],
            'notes' => $payment['notes'],
            'statut' => $statutIndex, // Index pour Flutter enum
            'date_creation' => $payment['date_creation'],
            'date_validation' => $payment['date_validation'],
            'last_modified_at' => $payment['last_modified_at'],
            'last_modified_by' => $payment['last_modified_by'],
            'is_synced' => (bool)$payment['is_synced'],
            'synced_at' => $payment['synced_at']
        ];
        
        $entities[] = $entity;
    }
    
    // Réponse de succès
    echo json_encode([
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'timestamp' => date('c'),
        'since' => $since,
        'user_role' => $userRole,
        'shop_id' => $shopId
    ]);

} catch (Exception $e) {
    error_log("❌ Erreur dans multi_month_payments changes.php: " . $e->getMessage());
    
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
