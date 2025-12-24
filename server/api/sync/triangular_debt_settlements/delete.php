<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once '../../../config/database.php';

try {
    // Récupération des données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['reference']) || !isset($data['user_id'])) {
        throw new Exception('Données invalides: reference et user_id requis');
    }
    
    $reference = $data['reference'];
    $userId = $data['user_id'];
    $userRole = $data['user_role'] ?? 'admin';
    $deleteReason = $data['delete_reason'] ?? 'Suppression par admin';
    $timestamp = date('Y-m-d H:i:s');
    
    // Vérifier les permissions (seul admin peut supprimer)
    if ($userRole !== 'admin') {
        throw new Exception('Permissions insuffisantes: seul admin peut supprimer');
    }
    
    // Vérifier que la régularisation existe
    $checkStmt = $pdo->prepare("SELECT * FROM triangular_debt_settlements WHERE reference = ?");
    $checkStmt->execute([$reference]);
    $settlement = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$settlement) {
        throw new Exception("Régularisation non trouvée: $reference");
    }
    
    // Marquer comme supprimé (soft delete)
    $updateStmt = $pdo->prepare("
        UPDATE triangular_debt_settlements 
        SET is_deleted = 1,
            deleted_at = ?,
            deleted_by = ?,
            delete_reason = ?,
            last_modified_at = ?,
            last_modified_by = ?
        WHERE reference = ?
    ");
    
    $updateStmt->execute([
        $timestamp,
        $userId,
        $deleteReason,
        $timestamp,
        $userId,
        $reference
    ]);
    
    if ($updateStmt->rowCount() === 0) {
        throw new Exception("Échec de la suppression pour: $reference");
    }
    
    // Log de l'action de suppression
    error_log("🗑️ Triangular settlement deleted: $reference by $userId");
    
    $response = [
        'success' => true,
        'message' => 'Régularisation supprimée avec succès',
        'reference' => $reference,
        'deleted_at' => $timestamp,
        'deleted_by' => $userId,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("🗑️ Delete error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
