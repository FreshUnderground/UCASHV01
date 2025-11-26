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
    
    if (!$data || !isset($data['entities'])) {
        throw new Exception('Données JSON invalides');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('c');
    
    $uploaded = 0;
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Vérifier les champs requis
            if (!isset($entity['table_name']) || !isset($entity['record_id']) || !isset($entity['action'])) {
                throw new Exception('Champs requis manquants');
            }
            
            // Préparer les valeurs JSON
            $oldValues = isset($entity['old_values']) ? json_encode($entity['old_values']) : null;
            $newValues = isset($entity['new_values']) ? json_encode($entity['new_values']) : null;
            $changedFields = isset($entity['changed_fields']) ? json_encode($entity['changed_fields']) : null;
            
            // Si l'audit existe déjà, ne rien faire (pas de mise à jour)
            if (isset($entity['id'])) {
                $checkStmt = $pdo->prepare("SELECT id FROM audit_log WHERE id = ?");
                $checkStmt->execute([$entity['id']]);
                if ($checkStmt->fetch()) {
                    $uploaded++;
                    continue; // Skip, déjà synchronisé
                }
            }
            
            // Insérer l'audit
            $sql = "INSERT INTO audit_log (
                id, table_name, record_id, action, 
                old_values, new_values, changed_fields,
                user_id, user_role, username, shop_id,
                ip_address, device_info, reason,
                created_at
            ) VALUES (
                :id, :table_name, :record_id, :action,
                :old_values, :new_values, :changed_fields,
                :user_id, :user_role, :username, :shop_id,
                :ip_address, :device_info, :reason,
                :created_at
            )";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute([
                ':id' => $entity['id'] ?? null,
                ':table_name' => $entity['table_name'],
                ':record_id' => $entity['record_id'],
                ':action' => strtoupper($entity['action']),
                ':old_values' => $oldValues,
                ':new_values' => $newValues,
                ':changed_fields' => $changedFields,
                ':user_id' => $entity['user_id'] ?? null,
                ':user_role' => $entity['user_role'] ?? null,
                ':username' => $entity['username'] ?? null,
                ':shop_id' => $entity['shop_id'] ?? null,
                ':ip_address' => $entity['ip_address'] ?? null,
                ':device_info' => $entity['device_info'] ?? null,
                ':reason' => $entity['reason'] ?? null,
                ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s'),
            ]);
            
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
