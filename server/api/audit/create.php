<?php
/**
 * API: Créer un enregistrement d'audit
 * POST /api/audit/create.php
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

try {
    $data = json_decode(file_get_contents('php://input'), true);

    // Validation des données requises
    $requiredFields = ['table_name', 'record_id', 'action'];
    foreach ($requiredFields as $field) {
        if (!isset($data[$field])) {
            throw new Exception("Champ requis manquant: $field");
        }
    }

    // Préparer les valeurs JSON
    $oldValues = isset($data['old_values']) ? json_encode($data['old_values']) : null;
    $newValues = isset($data['new_values']) ? json_encode($data['new_values']) : null;
    $changedFields = isset($data['changed_fields']) ? json_encode($data['changed_fields']) : null;

    // Insérer l'audit
    $sql = "INSERT INTO audit_log (
        table_name, record_id, action, 
        old_values, new_values, changed_fields,
        user_id, user_role, username, shop_id,
        ip_address, device_info, reason,
        created_at
    ) VALUES (
        :table_name, :record_id, :action,
        :old_values, :new_values, :changed_fields,
        :user_id, :user_role, :username, :shop_id,
        :ip_address, :device_info, :reason,
        NOW()
    )";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':table_name' => $data['table_name'],
        ':record_id' => $data['record_id'],
        ':action' => strtoupper($data['action']),
        ':old_values' => $oldValues,
        ':new_values' => $newValues,
        ':changed_fields' => $changedFields,
        ':user_id' => $data['user_id'] ?? null,
        ':user_role' => $data['user_role'] ?? null,
        ':username' => $data['username'] ?? null,
        ':shop_id' => $data['shop_id'] ?? null,
        ':ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
        ':device_info' => $data['device_info'] ?? null,
        ':reason' => $data['reason'] ?? null,
    ]);

    $auditId = $pdo->lastInsertId();

    echo json_encode([
        'success' => true,
        'message' => 'Audit enregistré',
        'audit_id' => $auditId,
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
