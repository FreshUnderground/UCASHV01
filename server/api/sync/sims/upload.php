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
    
    error_log("📱 [SIMs Upload] Réception de " . count($entities) . " SIMs");
    
    foreach ($entities as $index => $sim) {
        try {
            // Validation des champs obligatoires
            if (empty($sim['numero'])) {
                throw new Exception("Numéro de SIM manquant pour l'entité $index");
            }
            if (empty($sim['operateur'])) {
                throw new Exception("Opérateur manquant pour l'entité $index");
            }
            if (empty($sim['shop_id'])) {
                throw new Exception("shop_id manquant pour l'entité $index");
            }
            
            $simId = $sim['id'] ?? null;
            
            // Vérifier si la SIM existe déjà
            $checkStmt = $conn->prepare("SELECT id FROM sims WHERE numero = ? LIMIT 1");
            $checkStmt->execute([$sim['numero']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing && (!$simId || $existing['id'] != $simId)) {
                // SIM existe déjà avec un autre ID - UPDATE
                $simId = $existing['id'];
            }
            
            if ($simId && $existing) {
                // UPDATE
                $stmt = $conn->prepare("
                    UPDATE sims SET
                        numero = ?,
                        operateur = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        solde_initial = ?,
                        solde_actuel = ?,
                        statut = ?,
                        motif_suspension = ?,
                        date_creation = ?,
                        date_suspension = ?,
                        cree_par = ?,
                        last_modified_at = ?,
                        last_modified_by = ?,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = ?
                ");
                
                $stmt->execute([
                    $sim['numero'],
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active',
                    $sim['motif_suspension'] ?? null,
                    $sim['date_creation'] ?? date('Y-m-d H:i:s'),
                    $sim['date_suspension'] ?? null,
                    $sim['cree_par'] ?? null,
                    $sim['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $sim['last_modified_by'] ?? null,
                    $simId
                ]);
                
                error_log("✏️ SIM mis à jour: {$sim['numero']} (ID: $simId)");
            } else {
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO sims (
                        numero, operateur, shop_id, shop_designation,
                        solde_initial, solde_actuel, statut, motif_suspension,
                        date_creation, date_suspension, cree_par,
                        last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $sim['numero'],
                    $sim['operateur'],
                    $sim['shop_id'],
                    $sim['shop_designation'] ?? null,
                    $sim['solde_initial'] ?? 0,
                    $sim['solde_actuel'] ?? 0,
                    $sim['statut'] ?? 'active',
                    $sim['motif_suspension'] ?? null,
                    $sim['date_creation'] ?? date('Y-m-d H:i:s'),
                    $sim['date_suspension'] ?? null,
                    $sim['cree_par'] ?? null,
                    $sim['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $sim['last_modified_by'] ?? null
                ]);
                
                $simId = $conn->lastInsertId();
                error_log("➕ Nouvelle SIM insérée: {$sim['numero']} (ID: $simId)");
            }
            
            $successCount++;
            
        } catch (Exception $e) {
            $errorCount++;
            $errorMsg = "Erreur SIM {$sim['numero']}: " . $e->getMessage();
            $errors[] = $errorMsg;
            error_log("❌ $errorMsg");
        }
    }
    
    error_log("✅ Upload SIMs terminé: $successCount succès, $errorCount erreurs");
    
    echo json_encode([
        'success' => true,
        'message' => "Upload terminé: $successCount SIMs synchronisées",
        'uploaded' => $successCount,
        'errors' => $errorCount,
        'error_details' => $errors
    ]);
    
} catch (Exception $e) {
    error_log("❌ [SIMs Upload] Erreur: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
