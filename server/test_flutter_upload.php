<?php
// Test Flutter upload with exact data structure
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config/database.php';
require_once 'classes/SyncManager.php';

try {
    // Get the raw input
    $input = file_get_contents('php://input');
    error_log("Raw input: " . $input);
    
    // Try to decode JSON
    $data = json_decode($input, true);
    error_log("Decoded data: " . print_r($data, true));
    
    if (!$data) {
        throw new Exception('Invalid JSON data');
    }
    
    if (!isset($data['entities'])) {
        throw new Exception('Missing entities in data');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('c');
    
    $syncManager = new SyncManager($pdo);
    $uploaded = 0;
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Add sync metadata
            $entity['last_modified_at'] = $timestamp;
            $entity['last_modified_by'] = $userId;
            $entity['is_synced'] = 1;
            $entity['synced_at'] = date('c');
            
            // Save the entity
            $syncManager->saveShop($entity);
            $uploaded++;
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload terminé',
        'uploaded' => $uploaded,
        'total' => count($entities),
        'errors' => $errors,
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