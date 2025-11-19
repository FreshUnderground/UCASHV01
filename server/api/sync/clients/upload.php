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
            // Vérifier si le client existe déjà
            $checkStmt = $pdo->prepare("
                SELECT id FROM clients 
                WHERE id = :id
            ");
            $checkStmt->execute([':id' => $entity['id'] ?? 0]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // Mise à jour du client existant
                $updateStmt = $pdo->prepare("
                    UPDATE clients SET
                        nom = :nom,
                        telephone = :telephone,
                        adresse = :adresse,
                        solde = :solde,
                        shop_id = :shop_id,
                        agent_id = :agent_id,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by
                    WHERE id = :id
                ");
                
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':nom' => $entity['nom'] ?? '',
                    ':telephone' => $entity['telephone'] ?? '',
                    ':adresse' => $entity['adresse'] ?? null,
                    ':solde' => $entity['solde'] ?? 0,
                    ':shop_id' => $entity['shop_id'] ?? 1,
                    ':agent_id' => $entity['agent_id'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId
                ]);
                
                // Marquer comme synchronisé après mise à jour réussie
                // Use the client's synced_at timestamp to maintain timezone consistency
                $syncedAt = $entity['synced_at'] ?? date('c'); // Use ISO 8601 format
                $syncStmt = $pdo->prepare("UPDATE clients SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
                $syncStmt->execute([
                    ':id' => $entity['id'],
                    ':synced_at' => $syncedAt
                ]);
                
                $updatedCount++;
            } else {
                // Insertion d'un nouveau client
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
                if ($shopId === null) {
                    $shopId = $entity['shop_id'] ?? 1;
                }
                
                // Résoudre agent_id depuis agent_username
                $agentId = null;
                if (isset($entity['agent_username']) && !empty($entity['agent_username'])) {
                    $agentStmt = $pdo->prepare("SELECT id FROM agents WHERE username = :username LIMIT 1");
                    $agentStmt->execute([':username' => $entity['agent_username']]);
                    $agent = $agentStmt->fetch(PDO::FETCH_ASSOC);
                    if ($agent) {
                        $agentId = $agent['id'];
                    }
                }
                if ($agentId === null) {
                    $agentId = $entity['agent_id'] ?? null;
                }
                
                $insertStmt = $pdo->prepare("
                    INSERT IGNORE INTO clients (
                        nom, telephone, adresse, solde, shop_id, shop_designation, agent_id, agent_username,
                        last_modified_at, last_modified_by, created_at
                    ) VALUES (
                        :nom, :telephone, :adresse, :solde, :shop_id, :shop_designation, :agent_id, :agent_username,
                        :last_modified_at, :last_modified_by, :created_at
                    )
                ");
                
                $insertStmt->execute([
                    ':nom' => $entity['nom'] ?? '',
                    ':telephone' => $entity['telephone'] ?? '',
                    ':adresse' => $entity['adresse'] ?? null,
                    ':solde' => $entity['solde'] ?? 0,
                    ':shop_id' => $shopId,
                    ':shop_designation' => $entity['shop_designation'] ?? null,
                    ':agent_id' => $agentId,
                    ':agent_username' => $entity['agent_username'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId,
                    ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s')
                ]);
                
                // Marquer comme synchronisé après insertion réussie
                // Use the client's synced_at timestamp to maintain timezone consistency
                $syncedAt = $entity['synced_at'] ?? date('c'); // Use ISO 8601 format
                $insertId = $pdo->lastInsertId();
                $syncStmt = $pdo->prepare("UPDATE clients SET is_synced = 1, synced_at = :synced_at WHERE id = :id");
                $syncStmt->execute([
                    ':id' => $insertId,
                    ':synced_at' => $syncedAt
                ]);
                
                $uploadedCount++;
            }
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
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