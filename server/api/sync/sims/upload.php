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
    
    error_log("SIMs upload - received: " . count($entities) . " entities");
    
    foreach ($entities as $entity) {
        try {
            // Ajouter les métadonnées de synchronisation
            $entity['last_modified_at'] = $timestamp;
            $entity['last_modified_by'] = $userId;
            
            // Validation des champs obligatoires
            if (empty($entity['numero'])) {
                throw new Exception("Numéro de SIM manquant");
            }
            if (empty($entity['operateur'])) {
                throw new Exception("Opérateur manquant pour {$entity['numero']}");
            }
            if (!isset($entity['shop_id']) || $entity['shop_id'] <= 0) {
                throw new Exception("shop_id manquant ou invalide pour {$entity['numero']}");
            }
            
            $shopId = (int)$entity['shop_id'];
            
            // Vérifier si la SIM existe déjà (par numero)
            $checkStmt = $pdo->prepare("SELECT id FROM sims WHERE numero = ? LIMIT 1");
            $checkStmt->execute([$entity['numero']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing) {
                // UPDATE
                $stmt = $pdo->prepare("
                    UPDATE sims SET
                        numero = ?,
                        operateur = ?,
                        shop_id = ?,
                        shop_designation = ?,
                        solde_initial = ?,
                        solde_actuel = ?,
                        solde_initial_cdf = ?,
                        solde_actuel_cdf = ?,
                        solde_initial_usd = ?,
                        solde_actuel_usd = ?,
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
                    $entity['numero'],
                    $entity['operateur'],
                    $shopId,
                    $entity['shop_designation'] ?? null,
                    $entity['solde_initial'] ?? 0,
                    $entity['solde_actuel'] ?? 0,
                    $entity['solde_initial_cdf'] ?? 0,
                    $entity['solde_actuel_cdf'] ?? 0,
                    $entity['solde_initial_usd'] ?? 0,
                    $entity['solde_actuel_usd'] ?? 0,
                    $entity['statut'] ?? 'active',
                    $entity['motif_suspension'] ?? null,
                    $entity['date_creation'] ?? date('Y-m-d H:i:s'),
                    $entity['date_suspension'] ?? null,
                    $entity['cree_par'] ?? null,
                    $entity['last_modified_at'],
                    $entity['last_modified_by'],
                    $existing['id']
                ]);
                
                $updated++;
                error_log("SIM updated: {$entity['numero']}");
            } else {
                // INSERT
                $stmt = $pdo->prepare("
                    INSERT INTO sims (
                        numero, operateur, shop_id, shop_designation,
                        solde_initial, solde_actuel, 
                        solde_initial_cdf, solde_actuel_cdf,
                        solde_initial_usd, solde_actuel_usd,
                        statut, motif_suspension,
                        date_creation, date_suspension, cree_par,
                        last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())
                ");
                
                $stmt->execute([
                    $entity['numero'],
                    $entity['operateur'],
                    $shopId,
                    $entity['shop_designation'] ?? null,
                    $entity['solde_initial'] ?? 0,
                    $entity['solde_actuel'] ?? 0,
                    $entity['solde_initial_cdf'] ?? 0,
                    $entity['solde_actuel_cdf'] ?? 0,
                    $entity['solde_initial_usd'] ?? 0,
                    $entity['solde_actuel_usd'] ?? 0,
                    $entity['statut'] ?? 'active',
                    $entity['motif_suspension'] ?? null,
                    $entity['date_creation'] ?? date('Y-m-d H:i:s'),
                    $entity['date_suspension'] ?? null,
                    $entity['cree_par'] ?? null,
                    $entity['last_modified_at'],
                    $entity['last_modified_by']
                ]);
                
                $uploaded++;
                error_log("SIM inserted: {$entity['numero']}");
            }
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
            error_log("SIM error: " . $e->getMessage());
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
    
    error_log("SIMs upload complete: $uploaded inserted, $updated updated");
    
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("SIMs upload error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
