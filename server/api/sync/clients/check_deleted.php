<?php
/**
 * API Endpoint: Check Deleted Clients
 * Allows checking which clients have been deleted from the server
 * 
 * Method: POST
 * Content-Type: application/json
 * 
 * Request Body:
 * {
 *   "client_ids": [1, 2, 3, 4, 5]
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "deleted_clients": [2, 4],
 *   "message": "2 client(s) supprimé(s) trouvé(s)"
 * }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Handle OPTIONS request (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only accept POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Méthode non autorisée. Utilisez POST.'
    ]);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Read JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON invalide: ' . json_last_error_msg());
    }
    
    // Validate required fields
    if (!isset($data['client_ids']) || !is_array($data['client_ids'])) {
        throw new Exception('Liste client_ids requise');
    }
    
    $clientIds = $data['client_ids'];
    
    if (empty($clientIds)) {
        echo json_encode([
            'success' => true,
            'deleted_clients' => [],
            'message' => 'Aucun client à vérifier',
            'timestamp' => date('c')
        ]);
        exit();
    }
    
    // Prepare placeholders for IN clause
    $placeholders = implode(',', array_fill(0, count($clientIds), '?'));
    
    // Find which IDs exist in the database
    $stmt = $pdo->prepare("SELECT id FROM clients WHERE id IN ($placeholders)");
    $stmt->execute($clientIds);
    $existingIds = $stmt->fetchAll(PDO::FETCH_COLUMN, 0);
    $existingIds = array_map('intval', $existingIds);
    
    // Deleted clients are those in the request but not in the database
    $deletedClients = array_diff($clientIds, $existingIds);
    $deletedClients = array_values($deletedClients); // Re-index array
    
    $message = count($deletedClients) > 0
        ? count($deletedClients) . ' client(s) supprimé(s) trouvé(s)'
        : 'Aucun client supprimé trouvé';
    
    echo json_encode([
        'success' => true,
        'deleted_clients' => $deletedClients,
        'checked_count' => count($clientIds),
        'deleted_count' => count($deletedClients),
        'message' => $message,
        'timestamp' => date('c')
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'deleted_clients' => [],
        'timestamp' => date('c')
    ]);
    
    error_log("❌ Erreur check_deleted clients: " . $e->getMessage());
}
?>
