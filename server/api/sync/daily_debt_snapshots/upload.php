<?php
/**
 * Endpoint pour uploader les snapshots de dettes intershop
 * Reçoit les snapshots pré-calculés depuis l'application Flutter
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');
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

// Capturer les erreurs fatales
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Erreur PHP fatale: ' . $error['message'],
            'file' => $error['file'],
            'line' => $error['line']
        ]);
    }
});

// Vérifier que les fichiers requis existent
if (!file_exists(__DIR__ . '/../../../config/database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier de configuration database.php introuvable'
    ]);
    exit;
}

if (!file_exists(__DIR__ . '/../../../classes/Database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier Database.php introuvable'
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/Database.php';

try {
    error_log("[DAILY_DEBT_SNAPSHOTS] Upload request received");
    error_log("[DAILY_DEBT_SNAPSHOTS] Request method: " . $_SERVER['REQUEST_METHOD']);
    
    // Lire les données POST
    $input = file_get_contents('php://input');
    error_log("[DAILY_DEBT_SNAPSHOTS] Input length: " . strlen($input));
    
    if (empty($input)) {
        throw new Exception('Aucune donnée reçue dans la requête');
    }
    
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Erreur de décodage JSON: ' . json_last_error_msg());
    }
    
    error_log("[DAILY_DEBT_SNAPSHOTS] JSON décodé avec succès");
    
    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Données invalides: entities requis');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $uploadedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    // Connexion à la base de données
    $db = Database::getInstance()->getConnection();
    
    // Test connection
    try {
        $stmt = $db->query("SELECT 1");
        error_log("[DAILY_DEBT_SNAPSHOTS] Database connection successful");
    } catch (Exception $e) {
        error_log("[DAILY_DEBT_SNAPSHOTS] Database connection failed: " . $e->getMessage());
        throw new Exception("Database connection failed: " . $e->getMessage());
    }
    
    // Début de transaction
    $db->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
            error_log("[DAILY_DEBT_SNAPSHOTS] Processing snapshot: shop_id={$entity['shop_id']}, other_shop_id={$entity['other_shop_id']}, date={$entity['date']}");
            
            // Validation des champs obligatoires
            if (!isset($entity['shop_id']) || !isset($entity['other_shop_id']) || !isset($entity['date'])) {
                throw new Exception("Champs obligatoires manquants pour snapshot");
            }
            
            // Vérifier si le snapshot existe déjà (basé sur la contrainte unique)
            $checkStmt = $db->prepare("
                SELECT id FROM daily_intershop_debt_snapshot 
                WHERE shop_id = :shop_id 
                  AND other_shop_id = :other_shop_id 
                  AND date = :date 
                LIMIT 1
            ");
            $checkStmt->execute([
                ':shop_id' => $entity['shop_id'],
                ':other_shop_id' => $entity['other_shop_id'],
                ':date' => $entity['date']
            ]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // UPDATE
                $updateSql = "
                    UPDATE daily_intershop_debt_snapshot SET
                        dette_anterieure = :dette_anterieure,
                        creances_du_jour = :creances_du_jour,
                        dettes_du_jour = :dettes_du_jour,
                        solde_cumule = :solde_cumule,
                        updated_at = NOW(),
                        synced = 1,
                        sync_version = sync_version + 1
                    WHERE shop_id = :shop_id 
                      AND other_shop_id = :other_shop_id 
                      AND date = :date
                ";
                
                $updateStmt = $db->prepare($updateSql);
                $updateStmt->execute([
                    ':shop_id' => $entity['shop_id'],
                    ':other_shop_id' => $entity['other_shop_id'],
                    ':date' => $entity['date'],
                    ':dette_anterieure' => $entity['dette_anterieure'] ?? 0.0,
                    ':creances_du_jour' => $entity['creances_du_jour'] ?? 0.0,
                    ':dettes_du_jour' => $entity['dettes_du_jour'] ?? 0.0,
                    ':solde_cumule' => $entity['solde_cumule'] ?? 0.0,
                ]);
                
                $updatedCount++;
                error_log("✅ Snapshot updated: shop {$entity['shop_id']} ↔ shop {$entity['other_shop_id']} on {$entity['date']}");
                
            } else {
                // INSERT
                $insertSql = "
                    INSERT INTO daily_intershop_debt_snapshot (
                        shop_id, other_shop_id, date,
                        dette_anterieure, creances_du_jour, dettes_du_jour, solde_cumule,
                        created_at, updated_at,
                        synced, sync_version
                    ) VALUES (
                        :shop_id, :other_shop_id, :date,
                        :dette_anterieure, :creances_du_jour, :dettes_du_jour, :solde_cumule,
                        NOW(), NOW(),
                        1, 1
                    )
                ";
                
                $insertStmt = $db->prepare($insertSql);
                $insertStmt->execute([
                    ':shop_id' => $entity['shop_id'],
                    ':other_shop_id' => $entity['other_shop_id'],
                    ':date' => $entity['date'],
                    ':dette_anterieure' => $entity['dette_anterieure'] ?? 0.0,
                    ':creances_du_jour' => $entity['creances_du_jour'] ?? 0.0,
                    ':dettes_du_jour' => $entity['dettes_du_jour'] ?? 0.0,
                    ':solde_cumule' => $entity['solde_cumule'] ?? 0.0,
                ]);
                
                $uploadedCount++;
                error_log("✅ Snapshot created: shop {$entity['shop_id']} ↔ shop {$entity['other_shop_id']} on {$entity['date']}");
            }
            
        } catch (Exception $e) {
            $errors[] = [
                'entity' => $entity,
                'error' => $e->getMessage()
            ];
            error_log("❌ Error processing snapshot: " . $e->getMessage());
            // Continue processing other snapshots
        }
    }
    
    // Commit transaction
    $db->commit();
    
    $response = [
        'success' => true,
        'message' => 'Snapshots synchronisés avec succès',
        'uploaded_count' => $uploadedCount,
        'updated_count' => $updatedCount,
        'total_processed' => $uploadedCount + $updatedCount,
        'errors_count' => count($errors),
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    error_log("[DAILY_DEBT_SNAPSHOTS] Upload success: $uploadedCount created, $updatedCount updated");
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    
    error_log("[DAILY_DEBT_SNAPSHOTS] Upload error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'uploaded_count' => $uploadedCount ?? 0,
        'updated_count' => $updatedCount ?? 0,
        'timestamp' => date('c')
    ], JSON_UNESCAPED_UNICODE);
}
?>
