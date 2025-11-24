<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // Lire les données JSON
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data || !isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Format de données invalide');
    }
    
    $entities = $data['entities'];
    $successCount = 0;
    $errorCount = 0;
    $errors = [];
    
    error_log("📝 [SIM Movements Upload] Réception de " . count($entities) . " mouvements");
    
    foreach ($entities as $index => $movement) {
        try {
            // Validation des champs obligatoires
            if (empty($movement['sim_id'])) {
                throw new Exception("sim_id manquant pour l'entité $index");
            }
            if (empty($movement['sim_numero'])) {
                throw new Exception("sim_numero manquant pour l'entité $index");
            }
            if (empty($movement['nouveau_shop_id'])) {
                throw new Exception("nouveau_shop_id manquant pour l'entité $index");
            }
            
            $movementId = $movement['id'] ?? null;
            
            if ($movementId) {
                // Vérifier si le mouvement existe
                $checkStmt = $conn->prepare("SELECT id FROM sim_movements WHERE id = ? LIMIT 1");
                $checkStmt->execute([$movementId]);
                $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
                
                if ($existing) {
                    // UPDATE
                    $stmt = $conn->prepare("
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
                        $movement['sim_id'],
                        $movement['sim_numero'],
                        $movement['ancien_shop_id'] ?? null,
                        $movement['ancien_shop_designation'] ?? null,
                        $movement['nouveau_shop_id'],
                        $movement['nouveau_shop_designation'],
                        $movement['admin_responsable'],
                        $movement['motif'] ?? null,
                        $movement['date_movement'] ?? date('Y-m-d H:i:s'),
                        $movement['last_modified_at'] ?? date('Y-m-d H:i:s'),
                        $movement['last_modified_by'] ?? null,
                        $movementId
                    ]);
                    
                    error_log("✏️ Mouvement mis à jour: SIM {$movement['sim_numero']} (ID: $movementId)");
                } else {
                    $movementId = null; // Force INSERT si ID n'existe pas
                }
            }
            
            if (!$movementId) {
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO sim_movements (
                        sim_id, sim_numero, ancien_shop_id, ancien_shop_designation,
                        nouveau_shop_id, nouveau_shop_designation, admin_responsable,
                        motif, date_movement, last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $movement['sim_id'],
                    $movement['sim_numero'],
                    $movement['ancien_shop_id'] ?? null,
                    $movement['ancien_shop_designation'] ?? null,
                    $movement['nouveau_shop_id'],
                    $movement['nouveau_shop_designation'],
                    $movement['admin_responsable'],
                    $movement['motif'] ?? null,
                    $movement['date_movement'] ?? date('Y-m-d H:i:s'),
                    $movement['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $movement['last_modified_by'] ?? null
                ]);
                
                $movementId = $conn->lastInsertId();
                error_log("➕ Nouveau mouvement inséré: SIM {$movement['sim_numero']} (ID: $movementId)");
            }
            
            $successCount++;
            
        } catch (Exception $e) {
            $errorCount++;
            $errorMsg = "Erreur mouvement {$movement['sim_numero']}: " . $e->getMessage();
            $errors[] = $errorMsg;
            error_log("❌ $errorMsg");
        }
    }
    
    error_log("✅ Upload mouvements terminé: $successCount succès, $errorCount erreurs");
    
    echo json_encode([
        'success' => true,
        'message' => "Upload terminé: $successCount mouvements synchronisés",
        'uploaded' => $successCount,
        'errors' => $errorCount,
        'error_details' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("❌ [SIM Movements Upload] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
