<?php
// Désactiver l'affichage des erreurs pour éviter de corrompre le JSON
ini_set('display_errors', '0');
error_reporting(E_ALL);

// Capturer TOUTES les erreurs et les convertir en JSON
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
});

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
    
    error_log("💰 [Virtual Transactions Upload] Réception de " . count($entities) . " transactions");
    
    foreach ($entities as $index => $transaction) {
        try {
            // Validation des champs obligatoires
            if (empty($transaction['reference'])) {
                throw new Exception("Référence manquante pour l'entité $index");
            }
            if (!isset($transaction['montant_virtuel'])) {
                throw new Exception("Montant virtuel manquant pour l'entité $index");
            }
            if (!isset($transaction['montant_cash'])) {
                throw new Exception("Montant cash manquant pour l'entité $index");
            }
            if (empty($transaction['sim_numero'])) {
                throw new Exception("Numéro SIM manquant pour l'entité $index");
            }
            if (empty($transaction['shop_id'])) {
                throw new Exception("shop_id manquant pour l'entité $index");
            }
            if (empty($transaction['agent_id'])) {
                throw new Exception("agent_id manquant pour l'entité $index");
            }
            
            $transactionId = $transaction['id'] ?? null;
            
            // Vérifier si la transaction existe déjà
            $checkStmt = $conn->prepare("SELECT id FROM virtual_transactions WHERE reference = ? LIMIT 1");
            $checkStmt->execute([$transaction['reference']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing && (!$transactionId || $existing['id'] != $transactionId)) {
                // Transaction existe déjà avec un autre ID - UPDATE
                $transactionId = $existing['id'];
            }
            
            if ($transactionId && $existing) {
                // UPDATE
                $stmt = $conn->prepare("
                    UPDATE virtual_transactions SET
                        reference = ?,
                        montant_virtuel = ?,
                        frais = ?,
                        montant_cash = ?,
                        devise = ?,
                        sim_numero = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        agent_id = ?,
                        agent_username = ?,
                        client_nom = ?,
                        client_telephone = ?,
                        statut = ?,
                        date_enregistrement = ?,
                        date_validation = ?,
                        notes = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = ?
                ");
                
                $stmt->execute([
                    $transaction['reference'],
                    $transaction['montant_virtuel'],
                    $transaction['frais'] ?? 0,
                    $transaction['montant_cash'],
                    $transaction['devise'] ?? 'USD',
                    $transaction['sim_numero'],
                    $transaction['shop_id'],
                    $transaction['shop_designation'] ?? null,
                    $transaction['agent_id'],
                    $transaction['agent_username'] ?? null,
                    $transaction['client_nom'] ?? null,
                    $transaction['client_telephone'] ?? null,
                    $transaction['statut'] ?? 'enAttente',
                    $transaction['date_enregistrement'] ?? date('Y-m-d H:i:s'),
                    $transaction['date_validation'] ?? null,
                    $transaction['notes'] ?? null,
                    $transaction['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $transaction['last_modified_by'] ?? null,
                    $transactionId
                ]);
                
                error_log("✏️ Transaction mise à jour: {$transaction['reference']} (ID: $transactionId)");
            } else {
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO virtual_transactions (
                        reference, montant_virtuel, frais, montant_cash, devise,
                        sim_numero, shop_id, shop_designation,
                        agent_id, agent_username,
                        client_nom, client_telephone,
                        statut, date_enregistrement, date_validation, notes,
                        last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $transaction['reference'],
                    $transaction['montant_virtuel'],
                    $transaction['frais'] ?? 0,
                    $transaction['montant_cash'],
                    $transaction['devise'] ?? 'USD',
                    $transaction['sim_numero'],
                    $transaction['shop_id'],
                    $transaction['shop_designation'] ?? null,
                    $transaction['agent_id'],
                    $transaction['agent_username'] ?? null,
                    $transaction['client_nom'] ?? null,
                    $transaction['client_telephone'] ?? null,
                    $transaction['statut'] ?? 'enAttente',
                    $transaction['date_enregistrement'] ?? date('Y-m-d H:i:s'),
                    $transaction['date_validation'] ?? null,
                    $transaction['notes'] ?? null,
                    $transaction['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $transaction['last_modified_by'] ?? null
                ]);
                
                $transactionId = $conn->lastInsertId();
                error_log("➕ Nouvelle transaction insérée: {$transaction['reference']} (ID: $transactionId)");
            }
            
            $successCount++;
            
        } catch (Exception $e) {
            $errorCount++;
            $errorMsg = "Erreur Transaction {$transaction['reference']}: " . $e->getMessage();
            $errors[] = $errorMsg;
            error_log("❌ $errorMsg");
        }
    }
    
    error_log("✅ Upload Virtual Transactions terminé: $successCount succès, $errorCount erreurs");
    
    echo json_encode([
        'success' => true,
        'message' => "Upload terminé: $successCount transactions synchronisées",
        'uploaded' => $successCount,
        'errors' => $errorCount,
        'error_details' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("❌ [Virtual Transactions Upload] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
