<?php
/**
 * API: Download Deletion Requests 
 * Method: GET
 * Params: 
 *   - last_sync: timestamp (optional) - get only changes after this time
 *   - statut: filter by status (optional)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    $last_sync = $_GET['last_sync'] ?? null;
    $statut = $_GET['statut'] ?? null;
    
    // Construire la requête
    $query = "SELECT * FROM deletion_requests WHERE 1=1";
    
    if ($last_sync) {
        $query .= " AND last_modified_at > :last_sync";
    }
    
    if ($statut) {
        $query .= " AND statut = :statut";
    }
    
    $query .= " ORDER BY request_date DESC";
    
    $stmt = $db->prepare($query);
    
    if ($last_sync) {
        $stmt->bindParam(':last_sync', $last_sync);
    }
    
    if ($statut) {
        $stmt->bindParam(':statut', $statut);
    }
    
    $stmt->execute();
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Convertir les statuts MySQL vers index enum
    $statutMap = [
        'en_attente' => 0,
        'validee' => 1,
        'refusee' => 2,
        'annulee' => 3
    ];
    
    foreach ($requests as &$request) {
        $request['statut'] = $statutMap[$request['statut']] ?? 0;
    }
    
    echo json_encode([
        'success' => true,
        'data' => $requests,
        'count' => count($requests)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
?>
