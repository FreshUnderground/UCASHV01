<?php
/**
 * API: Download Virtual Transaction Deletion Requests
 * Method: GET
 * Returns all virtual transaction deletion requests for synchronization
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
    $since = $_GET['since'] ?? null;
    $userId = $_GET['user_id'] ?? 'unknown';
    
    error_log("[VT_DELETION_REQUESTS] Download request - since: " . ($since ?? 'null') . ", userId: " . $userId);
    
    // Build SQL query
    $sql = "SELECT * FROM virtual_transaction_deletion_requests WHERE 1=1";
    $params = [];
    
    if ($since && $since !== '') {
        $sql .= " AND last_modified_at > ?";
        $params[] = $since;
    }
    
    $sql .= " ORDER BY last_modified_at DESC";
    
    error_log("[VT_DELETION_REQUESTS] SQL query: " . $sql);
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    error_log("[VT_DELETION_REQUESTS] Found " . count($requests) . " deletion requests");
    
    // Convert data for Flutter with proper types
    $data = [];
    foreach ($requests as $request) {
        $data[] = [
            'id' => (int)$request['id'],
            'reference' => $request['reference'],
            'virtual_transaction_id' => $request['virtual_transaction_id'] ? (int)$request['virtual_transaction_id'] : null,
            'transaction_type' => $request['transaction_type'],
            'montant' => (float)$request['montant'],
            'devise' => $request['devise'],
            'destinataire' => $request['destinataire'],
            'expediteur' => $request['expediteur'],
            'client_nom' => $request['client_nom'],
            
            // Request information
            'requested_by_admin_id' => (int)$request['requested_by_admin_id'],
            'requested_by_admin_name' => $request['requested_by_admin_name'],
            'request_date' => $request['request_date'],
            'reason' => $request['reason'],
            
            // Admin validation
            'validated_by_admin_id' => $request['validated_by_admin_id'] ? (int)$request['validated_by_admin_id'] : null,
            'validated_by_admin_name' => $request['validated_by_admin_name'],
            'validation_admin_date' => $request['validation_admin_date'],
            
            // Agent validation
            'validated_by_agent_id' => $request['validated_by_agent_id'] ? (int)$request['validated_by_agent_id'] : null,
            'validated_by_agent_name' => $request['validated_by_agent_name'],
            'validation_date' => $request['validation_date'],
            
            // Status and tracking
            'statut' => $request['statut'],
            'last_modified_at' => $request['last_modified_at'],
            'last_modified_by' => $request['last_modified_by'],
            'created_at' => $request['created_at'],
            
            // Synchronization
            'is_synced' => (bool)$request['is_synced'],
            'synced_at' => $request['synced_at']
        ];
    }
    
    $response = [
        'success' => true,
        'data' => $data,
        'count' => count($data),
        'since' => $since,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("[VT_DELETION_REQUESTS] Download error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
