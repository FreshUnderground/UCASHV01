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

require_once '../../../config/database.php';

try {
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    $shopId = $_GET['shop_id'] ?? null;
    
    // Construire la requête SQL
    $sql = "SELECT * FROM reconciliations WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    if ($shopId) {
        $sql .= " AND shop_id = ?";
        $params[] = $shopId;
    }
    
    $sql .= " ORDER BY date_reconciliation DESC, last_modified_at DESC";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $reconciliations = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($reconciliations as $reconciliation) {
        $entities[] = [
            'id' => (int)$reconciliation['id'],
            'shop_id' => (int)$reconciliation['shop_id'],
            'date_reconciliation' => $reconciliation['date_reconciliation'],
            'periode' => $reconciliation['periode'],
            'capital_systeme_cash' => (float)$reconciliation['capital_systeme_cash'],
            'capital_systeme_airtel' => (float)$reconciliation['capital_systeme_airtel'],
            'capital_systeme_mpesa' => (float)$reconciliation['capital_systeme_mpesa'],
            'capital_systeme_orange' => (float)$reconciliation['capital_systeme_orange'],
            'capital_systeme_total' => (float)$reconciliation['capital_systeme_total'],
            'capital_reel_cash' => (float)$reconciliation['capital_reel_cash'],
            'capital_reel_airtel' => (float)$reconciliation['capital_reel_airtel'],
            'capital_reel_mpesa' => (float)$reconciliation['capital_reel_mpesa'],
            'capital_reel_orange' => (float)$reconciliation['capital_reel_orange'],
            'capital_reel_total' => (float)$reconciliation['capital_reel_total'],
            'ecart_cash' => isset($reconciliation['ecart_cash']) ? (float)$reconciliation['ecart_cash'] : null,
            'ecart_airtel' => isset($reconciliation['ecart_airtel']) ? (float)$reconciliation['ecart_airtel'] : null,
            'ecart_mpesa' => isset($reconciliation['ecart_mpesa']) ? (float)$reconciliation['ecart_mpesa'] : null,
            'ecart_orange' => isset($reconciliation['ecart_orange']) ? (float)$reconciliation['ecart_orange'] : null,
            'ecart_total' => isset($reconciliation['ecart_total']) ? (float)$reconciliation['ecart_total'] : null,
            'ecart_pourcentage' => isset($reconciliation['ecart_pourcentage']) ? (float)$reconciliation['ecart_pourcentage'] : null,
            'statut' => $reconciliation['statut'],
            'notes' => $reconciliation['notes'],
            'justification' => $reconciliation['justification'],
            'devise_secondaire' => $reconciliation['devise_secondaire'],
            'capital_systeme_devise2' => isset($reconciliation['capital_systeme_devise2']) ? (float)$reconciliation['capital_systeme_devise2'] : null,
            'capital_reel_devise2' => isset($reconciliation['capital_reel_devise2']) ? (float)$reconciliation['capital_reel_devise2'] : null,
            'ecart_devise2' => isset($reconciliation['ecart_devise2']) ? (float)$reconciliation['ecart_devise2'] : null,
            'action_corrective_requise' => (bool)$reconciliation['action_corrective_requise'],
            'action_corrective_prise' => $reconciliation['action_corrective_prise'],
            'created_by' => $reconciliation['created_by'] ? (int)$reconciliation['created_by'] : null,
            'verified_by' => $reconciliation['verified_by'] ? (int)$reconciliation['verified_by'] : null,
            'created_at' => $reconciliation['created_at'],
            'verified_at' => $reconciliation['verified_at'],
            'last_modified_at' => $reconciliation['last_modified_at'],
            'last_modified_by' => $reconciliation['last_modified_by'],
            'is_synced' => (bool)$reconciliation['is_synced'],
            'synced_at' => $reconciliation['synced_at'],
        ];
    }
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
