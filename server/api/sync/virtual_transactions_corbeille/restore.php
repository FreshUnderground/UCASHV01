<?php
/**
 * API: Restore Virtual Transaction from Corbeille
 * Method: POST
 * Body: {reference, restored_by, restoration_reason}
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

$rawInput = file_get_contents('php://input');
error_log("[VT_CORBEILLE] Restore - Raw input: " . $rawInput);

require_once __DIR__ . '/../../../config/database.php';

try {
    $data = json_decode($rawInput, true);
    
    if ($data === null && !empty($rawInput)) {
        parse_str($rawInput, $formData);
        $data = $formData;
    }
    
    $reference = $data['reference'] ?? null;
    $restoredBy = $data['restored_by'] ?? null;
    $restorationReason = $data['restoration_reason'] ?? null;
    
    error_log("[VT_CORBEILLE] Restore request - reference: $reference, restoredBy: $restoredBy");
    
    if (!$reference || !$restoredBy) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Champs requis manquants: reference, restored_by'
        ]);
        exit();
    }
    
    $db = $pdo;
    
    // Check if the item exists in corbeille and is not already restored
    $checkStmt = $db->prepare("SELECT * FROM virtual_transactions_corbeille WHERE reference = :reference AND is_restored = FALSE");
    $checkStmt->execute([':reference' => $reference]);
    $corbeilleItem = $checkStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$corbeilleItem) {
        error_log("[VT_CORBEILLE] Item not found or already restored: $reference");
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => "Transaction introuvable dans la corbeille ou déjà restaurée: $reference"
        ]);
        exit();
    }
    
    $db->beginTransaction();
    
    try {
        $now = date('Y-m-d H:i:s');
        
        // Restore the virtual transaction to the main table
        $restoreStmt = $db->prepare("
            INSERT INTO virtual_transactions (
                reference, montant_virtuel, frais, montant_cash, devise,
                sim_numero, shop_id, shop_designation, agent_id, agent_username,
                client_nom, client_telephone, statut, date_enregistrement, date_validation,
                notes, is_administrative, last_modified_at, last_modified_by, is_synced
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FALSE)
            ON DUPLICATE KEY UPDATE
                montant_virtuel = VALUES(montant_virtuel),
                frais = VALUES(frais),
                montant_cash = VALUES(montant_cash),
                devise = VALUES(devise),
                sim_numero = VALUES(sim_numero),
                shop_id = VALUES(shop_id),
                shop_designation = VALUES(shop_designation),
                agent_id = VALUES(agent_id),
                agent_username = VALUES(agent_username),
                client_nom = VALUES(client_nom),
                client_telephone = VALUES(client_telephone),
                statut = VALUES(statut),
                date_enregistrement = VALUES(date_enregistrement),
                date_validation = VALUES(date_validation),
                notes = VALUES(notes),
                is_administrative = VALUES(is_administrative),
                last_modified_at = VALUES(last_modified_at),
                last_modified_by = VALUES(last_modified_by),
                is_synced = FALSE
        ");
        
        $restoreStmt->execute([
            $corbeilleItem['reference'],
            $corbeilleItem['montant_virtuel'],
            $corbeilleItem['frais'],
            $corbeilleItem['montant_cash'],
            $corbeilleItem['devise'],
            $corbeilleItem['sim_numero'],
            $corbeilleItem['shop_id'],
            $corbeilleItem['shop_designation'],
            $corbeilleItem['agent_id'],
            $corbeilleItem['agent_username'],
            $corbeilleItem['client_nom'],
            $corbeilleItem['client_telephone'],
            $corbeilleItem['statut'],
            $corbeilleItem['date_enregistrement'],
            $corbeilleItem['date_validation'],
            $corbeilleItem['notes'],
            $corbeilleItem['is_administrative'],
            $now,
            $restoredBy
        ]);
        
        // Mark as restored in corbeille
        $markRestoredStmt = $db->prepare("
            UPDATE virtual_transactions_corbeille SET
                is_restored = TRUE,
                restored_by = :restored_by,
                restoration_date = :restoration_date,
                restoration_reason = :restoration_reason,
                last_modified_at = :last_modified_at,
                last_modified_by = :last_modified_by
            WHERE reference = :reference
        ");
        
        $markRestoredStmt->execute([
            ':restored_by' => $restoredBy,
            ':restoration_date' => $now,
            ':restoration_reason' => $restorationReason,
            ':last_modified_at' => $now,
            ':last_modified_by' => $restoredBy,
            ':reference' => $reference
        ]);
        
        $db->commit();
        
        error_log("[VT_CORBEILLE] Virtual transaction $reference successfully restored by $restoredBy");
        
        echo json_encode([
            'success' => true,
            'message' => "Transaction virtuelle restaurée avec succès",
            'reference' => $reference,
            'restored_by' => $restoredBy,
            'restoration_date' => $now
        ]);
        
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
    
} catch (PDOException $e) {
    error_log("[VT_CORBEILLE] DATABASE ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur base de données: ' . $e->getMessage(),
        'error_type' => 'PDOException'
    ]);
} catch (Exception $e) {
    error_log("[VT_CORBEILLE] GENERAL ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'error_type' => get_class($e)
    ]);
}
?>
