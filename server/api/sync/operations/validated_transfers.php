<?php
/**
 * API Endpoint: Get Validated Transfers
 * 
 * Récupère les transferts validés pour un shop spécifique.
 * Permet au shop SOURCE de voir quels transferts ont été servis par le shop DESTINATION.
 * 
 * ⚠️ IMPORTANT: Retourne toujours le champ 'reference' pour identifier les opérations
 * de manière universelle entre SQLite local et MySQL serveur.
 * 
 * METHOD: GET
 * PARAMS:
 *   - shop_id (required): ID du shop (SOURCE ou DESTINATION)
 *   - role (required): "source" ou "destination"
 *   - limit (optional): Nombre max de résultats (défaut: 50)
 *   - since (optional): Timestamp pour récupérer uniquement les changements récents
 * 
 * EXAMPLES:
 *   GET /validated_transfers.php?shop_id=1&role=source&limit=20
 *   GET /validated_transfers.php?shop_id=2&role=destination&since=2024-11-10T10:00:00Z
 * 
 * RESPONSE: {
 *   "success": true,
 *   "transfers": [...],
 *   "count": 15,
 *   "timestamp": "2024-11-10T10:30:00Z"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Gérer les requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Méthode non autorisée. Utilisez GET.'
    ]);
    exit;
}

require_once __DIR__ . '/../../../classes/Database.php';

try {
    // Récupérer les paramètres GET
    $shopId = isset($_GET['shop_id']) ? (int)$_GET['shop_id'] : null;
    $role = isset($_GET['role']) ? $_GET['role'] : null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $since = isset($_GET['since']) ? $_GET['since'] : null;
    
    // Valider les paramètres requis
    if (!$shopId) {
        throw new Exception('Paramètre shop_id requis');
    }
    
    if (!$role || !in_array($role, ['source', 'destination'])) {
        throw new Exception('Paramètre role requis. Valeurs: source ou destination');
    }
    
    // Limiter la taille des résultats
    if ($limit > 200) {
        $limit = 200;
    }
    
    // Connexion à la base de données
    $db = Database::getInstance()->getConnection();
    
    // Construire la requête selon le rôle
    $query = "
        SELECT 
            o.*,
            s_source.designation as shop_source_nom,
            s_dest.designation as shop_destination_nom,
            a.username as agent_username,
            a.nom as agent_nom,
            c.nom as client_nom
        FROM operations o
        LEFT JOIN shops s_source ON o.shop_source_id = s_source.id
        LEFT JOIN shops s_dest ON o.shop_destination_id = s_dest.id
        LEFT JOIN agents a ON o.agent_id = a.id
        LEFT JOIN clients c ON o.client_id = c.id
        WHERE 
            o.type IN ('transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant')
            AND o.statut IN ('validee', 'terminee')
    ";
    
    $params = [];
    
    // Filtrer selon le rôle
    if ($role === 'source') {
        // Transferts ENVOYÉS par ce shop (qui ont été validés par la destination)
        $query .= " AND o.shop_source_id = :shop_id";
        $params[':shop_id'] = $shopId;
    } else {
        // Transferts REÇUS et SERVIS par ce shop
        $query .= " AND o.shop_destination_id = :shop_id";
        $params[':shop_id'] = $shopId;
    }
    
    // Filtrer par date si spécifié
    if ($since) {
        $query .= " AND o.last_modified_at >= :since";
        $params[':since'] = $since;
    }
    
    // Trier par date de modification (plus récents en premier)
    $query .= " ORDER BY o.last_modified_at DESC LIMIT :limit";
    
    $stmt = $db->prepare($query);
    
    // Bind des paramètres
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    
    $stmt->execute();
    $transfers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les résultats
    $formattedTransfers = array_map(function($transfer) {
        return [
            'id' => (int)$transfer['id'],
            'reference' => $transfer['reference'],  // IMPORTANT: Clé unique universelle
            'type' => $transfer['type'],
            'statut' => $transfer['statut'],
            'montant_brut' => (float)$transfer['montant_brut'],
            'montant_net' => (float)$transfer['montant_net'],
            'commission' => (float)$transfer['commission'],
            'devise' => $transfer['devise'],
            'destinataire' => $transfer['destinataire'],
            'telephone_destinataire' => $transfer['telephone_destinataire'],
            'mode_paiement' => $transfer['mode_paiement'],
            'reference' => $transfer['reference'],
            'notes' => $transfer['notes'],
            
            // Informations sur les shops
            'shop_source_id' => (int)$transfer['shop_source_id'],
            'shop_source_nom' => $transfer['shop_source_nom'],
            'shop_destination_id' => (int)$transfer['shop_destination_id'],
            'shop_destination_nom' => $transfer['shop_destination_nom'],
            
            // Informations sur l'agent
            'agent_id' => (int)$transfer['agent_id'],
            'agent_username' => $transfer['agent_username'],
            'agent_nom' => $transfer['agent_nom'],
            
            // Informations sur le client
            'client_id' => $transfer['client_id'] ? (int)$transfer['client_id'] : null,
            'client_nom' => $transfer['client_nom'],
            
            // Métadonnées
            'date_operation' => $transfer['date_operation'],
            'created_at' => $transfer['created_at'],
            'last_modified_at' => $transfer['last_modified_at'],
            'last_modified_by' => $transfer['last_modified_by'],
            'is_synced' => (bool)$transfer['is_synced'],
        ];
    }, $transfers);
    
    // Log de succès
    error_log("✅ Récupération des transferts validés: shop $shopId ($role), {count: " . count($formattedTransfers) . "}");
    
    // Réponse de succès
    echo json_encode([
        'success' => true,
        'transfers' => $formattedTransfers,
        'count' => count($formattedTransfers),
        'role' => $role,
        'shop_id' => $shopId,
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    error_log("❌ Erreur récupération transferts validés: " . $e->getMessage());
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
?>
