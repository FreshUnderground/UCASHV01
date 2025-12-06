<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    require_once '../../../config/database.php';
    
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    $shopId = $_GET['shop_id'] ?? null; // Filtre optionnel par shop
    
    error_log("Cloture caisse changes request - since: " . ($since ?? 'null') . ", userId: " . $userId . ", shopId: " . ($shopId ?? 'all'));
    
    // Construire la requête SQL
    $sql = "SELECT * FROM cloture_caisse WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    if ($shopId && $shopId !== '') {
        $sql .= " AND shop_id = ?";
        $params[] = $shopId;
    }
    
    $sql .= " ORDER BY date_cloture DESC, last_modified_at DESC";
    
    error_log("Cloture caisse SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $clotures = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("Cloture caisse found: " . count($clotures));
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($clotures as $cloture) {
        $entities[] = [
            'id' => (int)$cloture['id'],
            'shop_id' => (int)$cloture['shop_id'],
            'date_cloture' => $cloture['date_cloture'],
            // IMPORTANT: Inclure solde_frais_anterieur pour que l'Admin voit les Frais
            'solde_frais_anterieur' => (float)($cloture['solde_frais_anterieur'] ?? 0),
            'solde_saisi_cash' => (float)$cloture['solde_saisi_cash'],
            'solde_saisi_airtel_money' => (float)$cloture['solde_saisi_airtel_money'],
            'solde_saisi_mpesa' => (float)$cloture['solde_saisi_mpesa'],
            'solde_saisi_orange_money' => (float)$cloture['solde_saisi_orange_money'],
            'solde_saisi_total' => (float)$cloture['solde_saisi_total'],
            'solde_calcule_cash' => (float)$cloture['solde_calcule_cash'],
            'solde_calcule_airtel_money' => (float)$cloture['solde_calcule_airtel_money'],
            'solde_calcule_mpesa' => (float)$cloture['solde_calcule_mpesa'],
            'solde_calcule_orange_money' => (float)$cloture['solde_calcule_orange_money'],
            'solde_calcule_total' => (float)$cloture['solde_calcule_total'],
            'ecart_cash' => (float)$cloture['ecart_cash'],
            'ecart_airtel_money' => (float)$cloture['ecart_airtel_money'],
            'ecart_mpesa' => (float)$cloture['ecart_mpesa'],
            'ecart_orange_money' => (float)$cloture['ecart_orange_money'],
            'ecart_total' => (float)$cloture['ecart_total'],
            'cloture_par' => $cloture['cloture_par'],
            'date_enregistrement' => $cloture['date_enregistrement'],
            'notes' => $cloture['notes'],
            'created_at' => $cloture['created_at'],
            'last_modified_at' => $cloture['last_modified_at'],
            'last_modified_by' => $cloture['last_modified_by'],
            'is_synced' => (bool)($cloture['is_synced'] ?? 1),
            'synced_at' => $cloture['synced_at'] ?? $cloture['created_at']
        ];
    }
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'shop_id' => $shopId,
        'timestamp' => date('c')
    ];
    
    error_log("Cloture caisse response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Cloture caisse error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
