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
    $updated = 0;
    $errors = [];
    
    error_log("SIM Movements upload - received: " . count($entities) . " entities");
    
    foreach ($entities as $entity) {
        try {
            // Ajouter les métadonnées de synchronisation
            $entity['last_modified_at'] = $timestamp;
            $entity['last_modified_by'] = $userId;
            
            // Validation des champs obligatoires
            if (empty($entity['sim_id'])) {
                throw new Exception("sim_id manquant");
            }
            if (empty($entity['sim_numero'])) {
                throw new Exception("sim_numero manquant");
            }
            if (empty($entity['nouveau_shop_id'])) {
                throw new Exception("nouveau_shop_id manquant pour SIM {$entity['sim_numero']}");
            }
            if (empty($entity['admin_responsable'])) {
                throw new Exception("admin_responsable manquant pour SIM {$entity['sim_numero']}");
            }
            
            $movementId = $entity['id'] ?? null;
            
            if ($movementId) {
                // Vérifier si le mouvement existe
                $checkStmt = $pdo->prepare("SELECT id FROM sim_movements WHERE id = ? LIMIT 1");
                $checkStmt->execute([$movementId]);
                $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
                
                if ($existing) {
                    // UPDATE
                    $stmt = $pdo->prepare("
                        UPDATE sim_movements SET
                            sim_id = ?,
                            sim_numero = ?,
                            ancien_shop_id = ?,
                            ancien_shop_designation = ?,
                            nouveau_shop_id = ?,
                            nouveau_shop_designation = ?,
                            admin_responsable = ?,
                            motif = ?,
                            date_movement = ?,
                            last_modified_at = ?,
                            last_modified_by = ?,
                            is_synced = 1,
                            synced_at = NOW()
                        WHERE id = ?
                    ");
                    
                    $stmt->execute([
                        $entity['sim_id'],
                        $entity['sim_numero'],
                        $entity['ancien_shop_id'] ?? null,
                        $entity['ancien_shop_designation'] ?? null,
                        $entity['nouveau_shop_id'],
                        $entity['nouveau_shop_designation'] ?? null,
                        $entity['admin_responsable'],
                        $entity['motif'] ?? null,
                        $entity['date_movement'] ?? date('Y-m-d H:i:s'),
                        $entity['last_modified_at'],
                        $entity['last_modified_by'],
                        $movementId
                    ]);
                    
                    $updated++;
                    error_log("SIM Movement updated: {$entity['sim_numero']}");
                } else {
                    $movementId = null; // Force INSERT si ID n'existe pas
                }
            }
            
            if (!$movementId) {
                // INSERT
                $stmt = $pdo->prepare("
                    INSERT INTO sim_movements (
                        sim_id, sim_numero, ancien_shop_id, ancien_shop_designation,
                        nouveau_shop_id, nouveau_shop_designation, admin_responsable,
                        motif, date_movement, last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $entity['sim_id'],
                    $entity['sim_numero'],
                    $entity['ancien_shop_id'] ?? null,
                    $entity['ancien_shop_designation'] ?? null,
                    $entity['nouveau_shop_id'],
                    $entity['nouveau_shop_designation'] ?? null,
                    $entity['admin_responsable'],
                    $entity['motif'] ?? null,
                    $entity['date_movement'] ?? date('Y-m-d H:i:s'),
                    $entity['last_modified_at'],
                    $entity['last_modified_by']
                ]);
                
                $uploaded++;
                error_log("SIM Movement inserted: {$entity['sim_numero']}");
            }
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
            error_log("SIM Movement error: " . $e->getMessage());
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload terminé',
        'uploaded' => $uploaded,
        'updated' => $updated,
        'total' => count($entities),
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    error_log("SIM Movements upload complete: $uploaded inserted, $updated updated");
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("SIM Movements upload error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
