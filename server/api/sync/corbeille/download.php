<?php
/**
 * API: Download Operations Corbeille (Trash Bin)
 * Method: GET
 * Params:
 *   - last_sync: timestamp (optional)
 *   - is_restored: 0 or 1 (optional) - filter by restoration status
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
    $is_restored = $_GET['is_restored'] ?? null;
    
    $query = "SELECT * FROM operations_corbeille WHERE 1=1";
    
    if ($last_sync) {
        $query .= " AND deleted_at > :last_sync";
    }
    
    if ($is_restored !== null) {
        $query .= " AND is_restored = :is_restored";
    }
    
    $query .= " ORDER BY deleted_at DESC";
    
    $stmt = $db->prepare($query);
    
    if ($last_sync) {
        $stmt->bindParam(':last_sync', $last_sync);
    }
    
    if ($is_restored !== null) {
        $stmt->bindParam(':is_restored', $is_restored);
    }
    
    $stmt->execute();
    $corbeille = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'data' => $corbeille,
        'count' => count($corbeille)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage()
    ]);
}
?>
