<?php
/**
 * API Endpoint: Delete Client
 * Allows deletion of a client from the server database
 * 
 * Method: POST
 * Content-Type: application/json
 * 
 * Request Body:
 * {
 *   "id": 123
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "message": "Client supprimé avec succès",
 *   "deleted_id": 123
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
    if (!isset($data['id']) || empty($data['id'])) {
        throw new Exception('ID du client requis');
    }
    
    $clientId = intval($data['id']);
    
    // Verify client exists
    $checkStmt = $pdo->prepare("SELECT id, nom FROM clients WHERE id = :id");
    $checkStmt->execute([':id' => $clientId]);
    $client = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$client) {
        throw new Exception("Client avec l'ID $clientId introuvable");
    }
    
    // Check if client has associated operations
    $opsCheckStmt = $pdo->prepare("SELECT COUNT(*) as count FROM operations WHERE client_id = :client_id");
    $opsCheckStmt->execute([':client_id' => $clientId]);
    $opsCount = $opsCheckStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    if ($opsCount > 0) {
        // Option 1: Prevent deletion if operations exist (recommended)
        throw new Exception("Impossible de supprimer le client '{$client['nom']}': $opsCount opération(s) associée(s). Supprimez d'abord les opérations ou désactivez le client.");
        
        // Option 2: Allow deletion but warn (uncomment if needed)
        // error_log("AVERTISSEMENT: Suppression du client {$client['nom']} avec $opsCount opérations associées");
    }
    
    // Begin transaction
    $pdo->beginTransaction();
    
    try {
        // Delete the client
        $deleteStmt = $pdo->prepare("DELETE FROM clients WHERE id = :id");
        $deleteStmt->execute([':id' => $clientId]);
        
        // Commit transaction
        $pdo->commit();
        
        // Log the deletion
        error_log("✅ Client supprimé: ID={$clientId}, Nom={$client['nom']}");
        
        echo json_encode([
            'success' => true,
            'message' => "Client '{$client['nom']}' supprimé avec succès",
            'deleted_id' => $clientId,
            'client_name' => $client['nom'],
            'timestamp' => date('c')
        ]);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        throw new Exception("Erreur lors de la suppression: " . $e->getMessage());
    }
    
} catch (Exception $e) {
    // Rollback if transaction is active
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'timestamp' => date('c')
    ]);
    
    error_log("❌ Erreur suppression client: " . $e->getMessage());
}
?>
