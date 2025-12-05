<?php
/**
 * API: Upload Corbeille Items
 * Method: POST
 * Body: Array of corbeille items JSON
 */

// CRITICAL: Disable ALL output before JSON
ob_start();

// Disable error display
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// Capture fatal errors
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        ob_clean();
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'message' => 'Erreur PHP fatale: ' . $error['message'],
            'file' => $error['file'],
            'line' => $error['line']
        ]);
    }
});

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}

// Include config for database connection
require_once __DIR__ . '/../../../config/database.php';

try {
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    $json = file_get_contents('php://input');
    $items = json_decode($json, true);
    
    if (!is_array($items)) {
        throw new Exception('Invalid data format - expected array');
    }
    
    $inserted = 0;
    $updated = 0;
    $errors = [];
    
    foreach ($items as $item) {
        $codeOps = $item['code_ops'] ?? $item['codeOps'] ?? null;
        
        if (!$codeOps) {
            error_log("[CORBEILLE] Skipping item without code_ops");
            $errors[] = 'Missing code_ops';
            continue;
        }
        
        try {
            // Check if exists
            $stmt = $db->prepare("SELECT id FROM operations_corbeille WHERE code_ops = ?");
            $stmt->execute([$codeOps]);
            $exists = $stmt->fetch();
            
            if ($exists) {
                // Update existing
                $stmt = $db->prepare("
                    UPDATE operations_corbeille SET
                        is_restored = :is_restored,
                        restored_at = :restored_at,
                        restored_by = :restored_by,
                        is_synced = 1
                    WHERE code_ops = :code_ops
                ");
                
                $stmt->execute([
                    ':is_restored' => $item['is_restored'] ?? $item['isRestored'] ?? 0,
                    ':restored_at' => $item['restored_at'] ?? $item['restoredAt'] ?? null,
                    ':restored_by' => $item['restored_by'] ?? $item['restoredBy'] ?? null,
                    ':code_ops' => $codeOps
                ]);
                
                $updated++;
            } else {
                // Insert new
                $stmt = $db->prepare("
                    INSERT INTO operations_corbeille (
                        original_operation_id, code_ops, type,
                        shop_source_id, shop_source_designation,
                        shop_destination_id, shop_destination_designation,
                        agent_id, agent_username,
                        client_id, client_nom,
                        montant_brut, commission, montant_net, devise,
                        mode_paiement, destinataire, telephone_destinataire,
                        reference, sim_numero, statut, notes, observation,
                        date_op, date_validation,
                        created_at_original, last_modified_at_original, last_modified_by_original,
                        deleted_at, is_restored, is_synced
                    ) VALUES (
                        :original_operation_id, :code_ops, :type,
                        :shop_source_id, :shop_source_designation,
                        :shop_destination_id, :shop_destination_designation,
                        :agent_id, :agent_username,
                        :client_id, :client_nom,
                        :montant_brut, :commission, :montant_net, :devise,
                        :mode_paiement, :destinataire, :telephone_destinataire,
                        :reference, :sim_numero, :statut, :notes, :observation,
                        :date_op, :date_validation,
                        :created_at_original, :last_modified_at_original, :last_modified_by_original,
                        :deleted_at, :is_restored, :is_synced
                    )
                ");
                
                $stmt->execute([
                    ':original_operation_id' => $item['original_operation_id'] ?? $item['originalOperationId'] ?? null,
                    ':code_ops' => $codeOps,
                    ':type' => $item['type'] ?? 'TRANSFERT_NATIONAL',
                    ':shop_source_id' => $item['shop_source_id'] ?? $item['shopSourceId'] ?? null,
                    ':shop_source_designation' => $item['shop_source_designation'] ?? $item['shopSourceDesignation'] ?? null,
                    ':shop_destination_id' => $item['shop_destination_id'] ?? $item['shopDestinationId'] ?? null,
                    ':shop_destination_designation' => $item['shop_destination_designation'] ?? $item['shopDestinationDesignation'] ?? null,
                    ':agent_id' => $item['agent_id'] ?? $item['agentId'] ?? 0,
                    ':agent_username' => $item['agent_username'] ?? $item['agentUsername'] ?? null,
                    ':client_id' => $item['client_id'] ?? $item['clientId'] ?? null,
                    ':client_nom' => $item['client_nom'] ?? $item['clientNom'] ?? null,
                    ':montant_brut' => $item['montant_brut'] ?? $item['montantBrut'] ?? 0,
                    ':commission' => $item['commission'] ?? 0,
                    ':montant_net' => $item['montant_net'] ?? $item['montantNet'] ?? 0,
                    ':devise' => $item['devise'] ?? 'USD',
                    ':mode_paiement' => $item['mode_paiement'] ?? $item['modePaiement'] ?? 'cash',
                    ':destinataire' => $item['destinataire'] ?? null,
                    ':telephone_destinataire' => $item['telephone_destinataire'] ?? $item['telephoneDestinataire'] ?? null,
                    ':reference' => $item['reference'] ?? null,
                    ':sim_numero' => $item['sim_numero'] ?? $item['simNumero'] ?? null,
                    ':statut' => $item['statut'] ?? 'terminee',
                    ':notes' => $item['notes'] ?? null,
                    ':observation' => $item['observation'] ?? null,
                    ':date_op' => $item['date_op'] ?? $item['dateOp'] ?? date('Y-m-d H:i:s'),
                    ':date_validation' => $item['date_validation'] ?? $item['dateValidation'] ?? null,
                    ':created_at_original' => $item['created_at_original'] ?? $item['createdAtOriginal'] ?? null,
                    ':last_modified_at_original' => $item['last_modified_at_original'] ?? $item['lastModifiedAtOriginal'] ?? null,
                    ':last_modified_by_original' => $item['last_modified_by_original'] ?? $item['lastModifiedByOriginal'] ?? null,
                    ':deleted_at' => $item['deleted_at'] ?? $item['deletedAt'] ?? date('Y-m-d H:i:s'),
                    ':is_restored' => $item['is_restored'] ?? $item['isRestored'] ?? 0,
                    ':is_synced' => 1
                ]);
                
                $inserted++;
            }
        } catch (Exception $e) {
            error_log("[CORBEILLE] Error saving $codeOps: " . $e->getMessage());
            $errors[] = [
                'code_ops' => $codeOps,
                'error' => $e->getMessage()
            ];
        }
    }
    
    error_log("[CORBEILLE] Uploaded: $inserted inserted, $updated updated");
    
    ob_end_clean();
    echo json_encode([
        'success' => true,
        'message' => "Uploaded successfully",
        'inserted' => $inserted,
        'updated' => $updated,
        'errors' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("[CORBEILLE] ERROR: " . $e->getMessage());
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e),
        'trace' => $e->getTraceAsString()
    ]);
}
