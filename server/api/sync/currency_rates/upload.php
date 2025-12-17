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

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    require_once '../../../config/database.php';
    
    // Lire les données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['entities'])) {
        throw new Exception('Données invalides');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    
    error_log("Currency rates upload - " . count($entities) . " entities from user: " . $userId);
    
    $pdo->beginTransaction();
    
    $insertedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Validation des données requises
            if (!isset($entity['from_currency']) || !isset($entity['to_currency']) || !isset($entity['rate'])) {
                $errors[] = "Données manquantes pour le taux de change";
                continue;
            }
            
            $fromCurrency = $entity['from_currency'];
            $toCurrency = $entity['to_currency'];
            $rate = (float)$entity['rate'];
            $updatedBy = $entity['updated_by'] ?? $userId;
            
            // Vérifier si le taux existe déjà
            $checkSql = "SELECT id FROM currency_rates WHERE from_currency = ? AND to_currency = ? AND is_active = 1";
            $checkStmt = $pdo->prepare($checkSql);
            $checkStmt->execute([$fromCurrency, $toCurrency]);
            $existingRate = $checkStmt->fetch();
            
            if ($existingRate) {
                // Mettre à jour le taux existant
                $updateSql = "UPDATE currency_rates SET 
                    rate = ?, 
                    updated_at = CURRENT_TIMESTAMP, 
                    updated_by = ?
                    WHERE from_currency = ? AND to_currency = ? AND is_active = 1";
                
                $updateStmt = $pdo->prepare($updateSql);
                $updateStmt->execute([
                    $rate,
                    $updatedBy,
                    $fromCurrency,
                    $toCurrency
                ]);
                
                $updatedCount++;
                error_log("Currency rate updated: {$fromCurrency}/{$toCurrency} = {$rate}");
            } else {
                // Insérer un nouveau taux
                $insertSql = "INSERT INTO currency_rates 
                    (from_currency, to_currency, rate, updated_by, created_at, updated_at) 
                    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)";
                
                $insertStmt = $pdo->prepare($insertSql);
                $insertStmt->execute([
                    $fromCurrency,
                    $toCurrency,
                    $rate,
                    $updatedBy
                ]);
                
                $insertedCount++;
                error_log("Currency rate inserted: {$fromCurrency}/{$toCurrency} = {$rate}");
            }
            
        } catch (Exception $e) {
            $errors[] = "Erreur pour le taux {$fromCurrency}/{$toCurrency}: " . $e->getMessage();
            error_log("Currency rate error: " . $e->getMessage());
        }
    }
    
    $pdo->commit();
    
    $response = [
        'success' => true,
        'message' => "Synchronisation terminée",
        'inserted_count' => $insertedCount,
        'updated_count' => $updatedCount,
        'total_processed' => $insertedCount + $updatedCount,
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    error_log("Currency rates upload completed - inserted: {$insertedCount}, updated: {$updatedCount}");
    
    echo json_encode($response);
    
} catch (Exception $e) {
    if (isset($pdo)) {
        $pdo->rollBack();
    }
    
    error_log("Currency rates upload error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
