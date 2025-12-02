<?php
// Activer la capture d'erreurs pour retourner du JSON
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

// Vérifier que le fichier de config existe
if (!file_exists(__DIR__ . '/../../../config/database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier de configuration database.php introuvable',
        'path_checked' => __DIR__ . '/../../../config/database.php'
    ]);
    exit;
}

// Vérifier que la classe Database existe
if (!file_exists(__DIR__ . '/../../../classes/Database.php')) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Fichier Database.php introuvable',
        'path_checked' => __DIR__ . '/../../../classes/Database.php'
    ]);
    exit;
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../classes/Database.php';

try {
    error_log("[COMPTES_SPECIAUX] Upload request received");
    error_log("[COMPTES_SPECIAUX] Request method: " . $_SERVER['REQUEST_METHOD']);
    error_log("[COMPTES_SPECIAUX] Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
    
    // Lire les données POST
    $input = file_get_contents('php://input');
    error_log("[COMPTES_SPECIAUX] Input length: " . strlen($input));
    
    if (empty($input)) {
        throw new Exception('Aucune donnée reçue dans la requête');
    }
    
    $data = json_decode($input, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Erreur de décodage JSON: ' . json_last_error_msg());
    }
    
    error_log("[COMPTES_SPECIAUX] JSON décodé avec succès");
    error_log("[COMPTES_SPECIAUX] Données reçues: " . print_r($data, true));
    
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
        error_log("Database connection successful");
    } catch (Exception $e) {
        error_log("Database connection failed: " . $e->getMessage());
        throw new Exception("Database connection failed: " . $e->getMessage());
    }
    
    // Début de transaction
    $db->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
            error_log("[SYNC COMPTE_SPECIAL] ID={$entity['id']}, type={$entity['type']}, type_transaction={$entity['type_transaction']}, montant={$entity['montant']}");
            
            // Validation des champs obligatoires
            if (!isset($entity['type']) || !isset($entity['type_transaction']) || !isset($entity['montant'])) {
                throw new Exception("Champs obligatoires manquants pour transaction ID {$entity['id']}");
            }
            
            // Vérifier si la transaction existe déjà
            $checkStmt = $db->prepare("SELECT id FROM comptes_speciaux WHERE id = :id LIMIT 1");
            $checkStmt->execute([':id' => $entity['id']]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // UPDATE
                $updateSql = "
                    UPDATE comptes_speciaux SET
                        type = :type,
                        type_transaction = :type_transaction,
                        montant = :montant,
                        description = :description,
                        shop_id = :shop_id,
                        date_transaction = :date_transaction,
                        operation_id = :operation_id,
                        agent_id = :agent_id,
                        agent_username = :agent_username,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = :id
                ";
                
                $updateStmt = $db->prepare($updateSql);
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':type' => $entity['type'],
                    ':type_transaction' => $entity['type_transaction'],
                    ':montant' => $entity['montant'],
                    ':description' => $entity['description'] ?? '',
                    ':shop_id' => $entity['shop_id'] ?? null,
                    ':date_transaction' => $entity['date_transaction'] ?? date('Y-m-d H:i:s'),
                    ':operation_id' => $entity['operation_id'] ?? null,
                    ':agent_id' => $entity['agent_id'] ?? null,
                    ':agent_username' => $entity['agent_username'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $entity['last_modified_by'] ?? $userId,
                ]);
                
                $updatedCount++;
                error_log("✅ Compte spécial ID {$entity['id']} mis à jour");
                
            } else {
                // INSERT
                $insertSql = "
                    INSERT INTO comptes_speciaux (
                        id, type, type_transaction, montant, description,
                        shop_id, date_transaction, operation_id,
                        agent_id, agent_username,
                        created_at, last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (
                        :id, :type, :type_transaction, :montant, :description,
                        :shop_id, :date_transaction, :operation_id,
                        :agent_id, :agent_username,
                        :created_at, :last_modified_at, :last_modified_by,
                        1, NOW()
                    )
                ";
                
                $insertStmt = $db->prepare($insertSql);
                $insertStmt->execute([
                    ':id' => $entity['id'],
                    ':type' => $entity['type'],
                    ':type_transaction' => $entity['type_transaction'],
                    ':montant' => $entity['montant'],
                    ':description' => $entity['description'] ?? '',
                    ':shop_id' => $entity['shop_id'] ?? null,
                    ':date_transaction' => $entity['date_transaction'] ?? date('Y-m-d H:i:s'),
                    ':operation_id' => $entity['operation_id'] ?? null,
                    ':agent_id' => $entity['agent_id'] ?? null,
                    ':agent_username' => $entity['agent_username'] ?? null,
                    ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_at' => $entity['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    ':last_modified_by' => $entity['last_modified_by'] ?? $userId,
                ]);
                
                $uploadedCount++;
                error_log("✅ Compte spécial ID {$entity['id']} créé");
            }
            
        } catch (Exception $e) {
            error_log("❌ Erreur pour transaction ID {$entity['id']}: " . $e->getMessage());
            $errors[] = [
                'id' => $entity['id'],
                'error' => $e->getMessage()
            ];
        }
    }
    
    // Valider la transaction
    $db->commit();
    
    $response = [
        'success' => true,
        'message' => "Upload terminé: {$uploadedCount} créés, {$updatedCount} mis à jour",
        'uploaded' => $uploadedCount,
        'updated' => $updatedCount,
        'errors' => $errors,
        'error_count' => count($errors),
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    error_log("✅ Upload comptes spéciaux terminé: {$uploadedCount} créés, {$updatedCount} mis à jour, " . count($errors) . " erreurs");
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'uploaded' => 0,
        'updated' => 0,
        'errors' => [],
        'timestamp' => date('c')
    ]);
    error_log("❌ Erreur upload comptes spéciaux: " . $e->getMessage());
}
?>
