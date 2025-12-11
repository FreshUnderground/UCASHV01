<?php
/**
 * API Endpoint pour la mise à jour d'un shop existant
 * POST /api/sync/shops/update.php
 * 
 * Cette API permet de modifier les informations d'un shop et notifie automatiquement
 * tous les agents associés à ce shop pour qu'ils resynchronisent leurs données.
 * 
 * Payload attendu:
 * {
 *   "shop_id": 123,
 *   "designation": "Nouveau nom",
 *   "localisation": "Nouvelle localisation",
 *   "capital_initial": 10000.0,
 *   "devise_principale": "USD",
 *   "devise_secondaire": "CDF",
 *   "capital_actuel": 10000.0,
 *   "capital_cash": 5000.0,
 *   "capital_airtel_money": 0.0,
 *   "capital_mpesa": 0.0,
 *   "capital_orange_money": 0.0,
 *   "user_id": "admin",
 *   "timestamp": "2025-12-11T10:00:00Z"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Méthode non autorisée. Utilisez POST.',
        'timestamp' => date('c')
    ]);
    exit();
}

require_once '../../../config/database.php';
require_once '../../../classes/SyncManager.php';

try {
    // Récupération et validation des données
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data) {
        throw new Exception('Données JSON invalides ou vides');
    }
    
    // Validation des champs obligatoires
    $shopId = $data['shop_id'] ?? null;
    if (!$shopId) {
        throw new Exception('shop_id est requis');
    }
    
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('c');
    
    // Log de la requête
    error_log("Shop Update Request - Shop ID: $shopId, User: $userId");
    
    // Vérifier que le shop existe
    $checkStmt = $pdo->prepare("SELECT id, designation FROM shops WHERE id = ?");
    $checkStmt->execute([$shopId]);
    $existingShop = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existingShop) {
        throw new Exception("Shop avec ID $shopId introuvable");
    }
    
    $oldDesignation = $existingShop['designation'];
    
    // Préparer les données pour la mise à jour
    $updateData = [
        'id' => $shopId,
        'designation' => $data['designation'] ?? $oldDesignation,
        'localisation' => $data['localisation'] ?? '',
        'capital_initial' => $data['capital_initial'] ?? 0,
        'devise_principale' => $data['devise_principale'] ?? 'USD',
        'devise_secondaire' => $data['devise_secondaire'] ?? null,
        'capital_actuel' => $data['capital_actuel'] ?? 0,
        'capital_cash' => $data['capital_cash'] ?? 0,
        'capital_airtel_money' => $data['capital_airtel_money'] ?? 0,
        'capital_mpesa' => $data['capital_mpesa'] ?? 0,
        'capital_orange_money' => $data['capital_orange_money'] ?? 0,
        'capital_actuel_devise2' => $data['capital_actuel_devise2'] ?? null,
        'capital_cash_devise2' => $data['capital_cash_devise2'] ?? null,
        'capital_airtel_money_devise2' => $data['capital_airtel_money_devise2'] ?? null,
        'capital_mpesa_devise2' => $data['capital_mpesa_devise2'] ?? null,
        'capital_orange_money_devise2' => $data['capital_orange_money_devise2'] ?? null,
        'creances' => $data['creances'] ?? 0,
        'dettes' => $data['dettes'] ?? 0,
        'last_modified_at' => $timestamp,
        'last_modified_by' => $userId,
        'synced_at' => $timestamp
    ];
    
    // Effectuer la mise à jour via SyncManager
    $syncManager = new SyncManager($pdo);
    $result = $syncManager->saveShop($updateData);
    
    if (!$result) {
        throw new Exception('Échec de la mise à jour du shop');
    }
    
    // Récupérer la liste des agents associés à ce shop pour notification
    $agentsStmt = $pdo->prepare("
        SELECT id, username, nom 
        FROM agents 
        WHERE shop_id = ? AND is_active = 1
    ");
    $agentsStmt->execute([$shopId]);
    $affectedAgents = $agentsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Marquer les agents pour resynchronisation (mise à jour last_modified_at du shop force le download)
    $agentIds = array_map(function($agent) {
        return $agent['id'];
    }, $affectedAgents);
    
    $response = [
        'success' => true,
        'message' => 'Shop mis à jour avec succès',
        'shop' => [
            'id' => $shopId,
            'designation' => $updateData['designation'],
            'old_designation' => $oldDesignation,
            'localisation' => $updateData['localisation']
        ],
        'affected_agents' => [
            'count' => count($affectedAgents),
            'agents' => array_map(function($agent) {
                return [
                    'id' => $agent['id'],
                    'username' => $agent['username'],
                    'nom' => $agent['nom']
                ];
            }, $affectedAgents)
        ],
        'notification' => [
            'type' => 'SHOP_UPDATED',
            'message' => 'Les agents du shop devront resynchroniser leurs données'
        ],
        'timestamp' => date('c')
    ];
    
    // Log de succès
    error_log("Shop Updated Successfully - ID: $shopId, Affected Agents: " . count($affectedAgents));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Shop Update Error: " . $e->getMessage());
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
