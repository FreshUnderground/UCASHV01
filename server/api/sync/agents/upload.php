<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Lire les données POST
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Données invalides: entities requis');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $uploadedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    // Début de transaction
    $pdo->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
            // Vérifier si l'agent existe déjà
            $checkStmt = $pdo->prepare("
                SELECT id FROM agents 
                WHERE id = :id
            ");
            $checkStmt->execute([':id' => $entity['id'] ?? 0]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // Mise à jour de l'agent existant
                $updateStmt = $pdo->prepare("
                    UPDATE agents SET
                        nom = :nom,
                        username = :username,
                        password = :password,
                        shop_id = :shop_id,
                        role = :role,
                        is_active = :is_active,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by
                    WHERE id = :id
                ");
                
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':nom' => $entity['nom'] ?? '',
                    ':username' => $entity['username'] ?? '',
                    ':password' => $entity['password'] ?? '',
                    ':shop_id' => $entity['shop_id'] ?? 1,
                    ':role' => $entity['role'] ?? 'AGENT',
                    ':is_active' => $entity['is_active'] ?? 1,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId
                ]);
                
                // Marquer comme synchronisé après mise à jour réussie
                // Use the client's synced_at timestamp to maintain timezone consistency
                $syncedAt = $entity['synced_at'] ?? date('c'); // Use ISO 8601 format
                $syncStmt = $pdo->prepare("UPDATE agents SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
                $syncStmt->execute([
                    ':id' => $entity['id'],
                    ':synced_at' => $syncedAt
                ]);
                
                $updatedCount++;
            } else {
                // Insertion d'un nouvel agent
                // Résoudre shop_id depuis shop_designation
                $shopId = null;
                if (isset($entity['shop_designation']) && !empty($entity['shop_designation'])) {
                    $shopStmt = $pdo->prepare("SELECT id FROM shops WHERE designation = :designation LIMIT 1");
                    $shopStmt->execute([':designation' => $entity['shop_designation']]);
                    $shop = $shopStmt->fetch(PDO::FETCH_ASSOC);
                    if ($shop) {
                        $shopId = $shop['id'];
                    }
                }
                
                // Si pas de shop_designation ou shop non trouvé, utiliser shop_id direct
                if ($shopId === null) {
                    $shopId = $entity['shop_id'] ?? 1;
                }
                
                $insertStmt = $pdo->prepare("
                    INSERT IGNORE INTO agents (
                        nom, username, password, shop_id, role, is_active,
                        last_modified_at, last_modified_by, created_at
                    ) VALUES (
                        :nom, :username, :password, :shop_id, :role, :is_active,
                        :last_modified_at, :last_modified_by, :created_at
                    )
                ");
                
                $insertStmt->execute([
                    ':nom' => $entity['nom'] ?? '',
                    ':username' => $entity['username'] ?? '',
                    ':password' => $entity['password'] ?? '',
                    ':shop_id' => $shopId,
                    ':role' => $entity['role'] ?? 'AGENT',
                    ':is_active' => $entity['is_active'] ?? 1,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId,
                    ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
                ]);
                
                // Marquer comme synchronisé après insertion réussie
                // Use the client's synced_at timestamp to maintain timezone consistency
                $syncedAt = $entity['synced_at'] ?? date('c'); // Use ISO 8601 format
                $insertId = $pdo->lastInsertId();
                $syncStmt = $pdo->prepare("UPDATE agents SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
                $syncStmt->execute([
                    ':id' => $insertId,
                    ':synced_at' => $syncedAt
                ]);
                
                $uploadedCount++;
            }
        } catch (Exception $e) {
            $errorMessage = $e->getMessage();
            
            // Détecter les erreurs de clé étrangère
            if (strpos($errorMessage, 'foreign key constraint') !== false || strpos($errorMessage, '1452') !== false) {
                $errorMessage = 'Le shop référencé (shop_id=' . ($entity['shop_id'] ?? 'unknown') . ') n\'existe pas. Synchronisez d\'abord les shops.';
            }
            
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $errorMessage
            ];
        }
    }
    
    // Commit de la transaction
    $pdo->commit();
    
    $response = [
        'success' => true,
        'message' => 'Synchronisation réussie',
        'uploaded' => $uploadedCount,
        'updated' => $updatedCount,
        'total' => $uploadedCount + $updatedCount,
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>