<?php
require_once '../../../config/database.php';
require_once '../../../classes/Database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

try {
    $db = Database::getInstance();
    $pdo = $db->getConnection();

    // Récupérer la date de dernière synchronisation depuis les paramètres GET
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';

    // Debug
    error_log("🔄 Changements demandés depuis: $since");

    // Requête pour obtenir les opérations modifiées depuis la dernière synchronisation
    $sql = "SELECT 
        o.id,
        o.type,
        o.montant_brut,
        o.montant_net,
        o.commission,
        o.devise,
        o.client_id,
        o.client_nom,
        o.shop_source_id,
        o.shop_source_designation,
        o.shop_destination_id,
        o.shop_destination_designation,
        o.agent_id,
        o.agent_username,
        o.mode_paiement,
        o.statut,
        o.reference,
        o.notes,
        o.destinataire,
        o.telephone_destinataire,
        o.last_modified_at,
        o.created_at,
        o.is_synced,
        ss.designation as source_shop_name,
        sd.designation as dest_shop_name,
        a.username as agent_name
    FROM operations o
    LEFT JOIN shops ss ON o.shop_source_id = ss.id
    LEFT JOIN shops sd ON o.shop_destination_id = sd.id
    LEFT JOIN agents a ON o.agent_id = a.id
    WHERE 1=1";
    
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND o.last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY o.last_modified_at ASC LIMIT 100";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $operations = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Convertir les données pour Flutter
    $entities = [];
    foreach ($operations as $operation) {
        $entities[] = [
            'id' => (int)$operation['id'],
            'type' => _convertTypeToIndex($operation['type']),  // Convertir en index
            'montant_brut' => (float)$operation['montant_brut'],
            'montant_net' => (float)$operation['montant_net'],
            'commission' => (float)$operation['commission'],
            'devise' => $operation['devise'] ?? 'USD',
            'client_id' => $operation['client_id'] ? (int)$operation['client_id'] : null,
            'client_nom' => $operation['client_nom'],
            'shop_source_id' => $operation['shop_source_id'] ? (int)$operation['shop_source_id'] : null,
            'shop_source_designation' => $operation['shop_source_designation'] ?? $operation['source_shop_name'],
            'shop_destination_id' => $operation['shop_destination_id'] ? (int)$operation['shop_destination_id'] : null,
            'shop_destination_designation' => $operation['shop_destination_designation'] ?? $operation['dest_shop_name'],
            'agent_id' => (int)$operation['agent_id'],
            'agent_username' => $operation['agent_username'] ?? $operation['agent_name'],
            'mode_paiement' => _convertModePaiementToIndex($operation['mode_paiement']),  // Convertir en index
            'statut' => _convertStatutToIndex($operation['statut']),  // Convertir en index
            'reference' => $operation['reference'],
            'notes' => $operation['notes'],
            'destinataire' => $operation['destinataire'],
            'telephone_destinataire' => $operation['telephone_destinataire'],
            'last_modified_at' => $operation['last_modified_at'],
            'date_op' => $operation['created_at'],
            'created_at' => $operation['created_at'],
            'is_synced' => (bool)$operation['is_synced']
        ];
    }

    // Debug
    error_log("📤 Opérations trouvées: " . count($entities));

    echo json_encode([
        'success' => true,
        'message' => 'Opérations récupérées avec succès',
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'timestamp' => date('c')
    ]);

} catch (Exception $e) {
    error_log("❌ Erreur dans changes.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'entities' => [],
        'count' => 0,
        'timestamp' => date('c')
    ]);
}

// Fonctions de conversion des valeurs SQL vers index d'enum Flutter
function _convertTypeToIndex($type) {
    // SQL vers Flutter enum index: transfertNational=0, transfertInternationalSortant=1, transfertInternationalEntrant=2, depot=3, retrait=4, virement=5
    // MySQL ENUM: 'depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant'
    $mapping = [
        'transfertNational' => 0,
        'transfertInternationalSortant' => 1,
        'transfertInternationalEntrant' => 2,
        'depot' => 3,
        'retrait' => 4,
        'virement' => 5
    ];
    return $mapping[$type] ?? 3; // Défaut: depot
}

function _convertModePaiementToIndex($mode) {
    // SQL vers Flutter enum index: cash=0, airtelMoney=1, mPesa=2, orangeMoney=3
    // MySQL ENUM: 'cash', 'airtelMoney', 'mPesa', 'orangeMoney'
    $mapping = [
        'cash' => 0,
        'airtelMoney' => 1,
        'mPesa' => 2,
        'orangeMoney' => 3
    ];
    return $mapping[$mode] ?? 0; // Défaut: cash
}

function _convertStatutToIndex($statut) {
    // SQL vers Flutter enum index: enAttente=0, validee=1, terminee=2, annulee=3
    // MySQL ENUM: 'enAttente', 'validee', 'terminee', 'annulee'
    $mapping = [
        'enAttente' => 0,
        'validee' => 1,
        'terminee' => 2,
        'annulee' => 3
    ];
    return $mapping[$statut] ?? 2; // Défaut: terminee
}
?>