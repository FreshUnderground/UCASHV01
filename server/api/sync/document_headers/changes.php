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
    
    error_log("Document headers changes request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Construire la requête SQL
    $sql = "SELECT * FROM document_headers WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at DESC";
    
    error_log("Document headers SQL query: " . $sql . " with params: " . print_r($params, true));
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $headers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("Document headers found: " . count($headers));
    
    // Convertir les données pour Flutter
    $entities = [];
    foreach ($headers as $header) {
        $entities[] = [
            'id' => (int)$header['id'],
            'company_name' => $header['company_name'],
            'company_slogan' => $header['company_slogan'],
            'address' => $header['address'],
            'phone' => $header['phone'],
            'email' => $header['email'],
            'website' => $header['website'],
            'logo_path' => $header['logo_path'],
            'tax_number' => $header['tax_number'],
            'registration_number' => $header['registration_number'],
            'is_active' => (int)$header['is_active'],
            'created_at' => $header['created_at'],
            'updated_at' => $header['updated_at'],
            'last_modified_at' => $header['last_modified_at'],
            'last_modified_by' => $header['last_modified_by'],
            'is_synced' => (bool)($header['is_synced'] ?? 1),
            'synced_at' => $header['synced_at'] ?? $header['created_at']
        ];
    }
    
    $response = [
        'success' => true,
        'entities' => $entities,
        'count' => count($entities),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    error_log("Document headers response count: " . count($entities));
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("Document headers error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
