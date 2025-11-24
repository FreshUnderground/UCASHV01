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
            // Log pour débogage - DÉTAILLÉ
            error_log("[COMMISSION UPLOAD] =====================================");
            error_log("[COMMISSION] ID={$entity['id']}");
            error_log("[COMMISSION] Type={$entity['type']}, Taux={$entity['taux']}");
            error_log("[COMMISSION] ShopId=" . ($entity['shop_id'] ?? 'NULL'));
            error_log("[COMMISSION] ShopSourceId=" . ($entity['shop_source_id'] ?? 'NULL'));
            error_log("[COMMISSION] ShopDestinationId=" . ($entity['shop_destination_id'] ?? 'NULL'));
            error_log("[COMMISSION] Description={$entity['description']}");
            
            // VALIDATION: Pour shop-to-shop, les deux IDs sont requis
            $hasSourceId = !empty($entity['shop_source_id']);
            $hasDestId = !empty($entity['shop_destination_id']);
            
            if ($hasSourceId && !$hasDestId) {
                error_log("❌ Commission invalide: shop_source_id sans shop_destination_id");
                throw new Exception("Une commission avec shop_source_id nécessite aussi shop_destination_id");
            }
            if (!$hasSourceId && $hasDestId) {
                error_log("❌ Commission invalide: shop_destination_id sans shop_source_id");
                throw new Exception("Une commission avec shop_destination_id nécessite aussi shop_source_id");
            }
            
            // Vérifier si la commission existe déjà
            $checkStmt = $pdo->prepare("
                SELECT id FROM commissions 
                WHERE id = :id
            ");
            $checkStmt->execute([':id' => $entity['id'] ?? 0]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // Mise à jour de la commission existante
                $updateStmt = $pdo->prepare("
                    UPDATE commissions SET
                        type = :type,
                        taux = :taux,
                        description = :description,
                        shop_id = :shop_id,
                        shop_source_id = :shop_source_id,
                        shop_destination_id = :shop_destination_id,
                        is_active = :is_active,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = :synced_at
                    WHERE id = :id
                ");
                
                $syncedAt = $entity['synced_at'] ?? date('c');
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':type' => $entity['type'] ?? 'SORTANT',
                    ':taux' => $entity['taux'] ?? 0,
                    ':description' => $entity['description'] ?? '',
                    ':shop_id' => $entity['shop_id'] ?? null,
                    ':shop_source_id' => $entity['shop_source_id'] ?? null,
                    ':shop_destination_id' => $entity['shop_destination_id'] ?? null,
                    ':is_active' => $entity['is_active'] ?? 1,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId,
                    ':synced_at' => $syncedAt
                ]);
                
                $updatedCount++;
                error_log("✅ Commission ID {$entity['id']} mise à jour - shopId=" . ($entity['shop_id'] ?? 'NULL') . ", sourceId=" . ($entity['shop_source_id'] ?? 'NULL') . ", destId=" . ($entity['shop_destination_id'] ?? 'NULL'));
            } else {
                // Insertion d'une nouvelle commission avec l'ID de l'app
                $insertStmt = $pdo->prepare("
                    INSERT INTO commissions (
                        id, type, taux, description, 
                        shop_id, shop_source_id, shop_destination_id,
                        is_active, last_modified_at, last_modified_by, created_at, is_synced, synced_at
                    ) VALUES (
                        :id, :type, :taux, :description,
                        :shop_id, :shop_source_id, :shop_destination_id,
                        :is_active, :last_modified_at, :last_modified_by, :created_at, 1, :synced_at
                    )
                ");
                
                $syncedAt = $entity['synced_at'] ?? date('c');
                $insertStmt->execute([
                    ':id' => $entity['id'],  // Utiliser l'ID de l'app
                    ':type' => $entity['type'] ?? 'SORTANT',
                    ':taux' => $entity['taux'] ?? 0,
                    ':description' => $entity['description'] ?? '',
                    ':shop_id' => $entity['shop_id'] ?? null,
                    ':shop_source_id' => $entity['shop_source_id'] ?? null,
                    ':shop_destination_id' => $entity['shop_destination_id'] ?? null,
                    ':is_active' => $entity['is_active'] ?? 1,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $userId,
                    ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s'),
                    ':synced_at' => $syncedAt
                ]);
                
                $uploadedCount++;
                error_log("✅ Commission ID {$entity['id']} insérée - shopId=" . ($entity['shop_id'] ?? 'NULL') . ", sourceId=" . ($entity['shop_source_id'] ?? 'NULL') . ", destId=" . ($entity['shop_destination_id'] ?? 'NULL'));
            }
        } catch (Exception $e) {
            error_log("❌ Erreur commission ID {$entity['id']}: {$e->getMessage()}");
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
    
    error_log("❌ Erreur globale: {$e->getMessage()}");
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}