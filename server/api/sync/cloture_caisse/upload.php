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
    
    foreach ($entities as $entity) {
        try {
            // Vérifier si l'entité existe déjà (clé unique: shop_id + date_cloture)
            $checkStmt = $pdo->prepare("SELECT id FROM cloture_caisse WHERE shop_id = ? AND date_cloture = ?");
            $checkStmt->execute([
                $entity['shop_id'],
                date('Y-m-d', strtotime($entity['date_cloture']))
            ]);
            $exists = $checkStmt->fetch();
            
            if ($exists) {
                // UPDATE
                $sql = "UPDATE cloture_caisse SET 
                        solde_frais_anterieur = ?,
                        solde_saisi_cash = ?,
                        solde_saisi_airtel_money = ?,
                        solde_saisi_mpesa = ?,
                        solde_saisi_orange_money = ?,
                        solde_saisi_total = ?,
                        solde_calcule_cash = ?,
                        solde_calcule_airtel_money = ?,
                        solde_calcule_mpesa = ?,
                        solde_calcule_orange_money = ?,
                        solde_calcule_total = ?,
                        ecart_cash = ?,
                        ecart_airtel_money = ?,
                        ecart_mpesa = ?,
                        ecart_orange_money = ?,
                        ecart_total = ?,
                        cloture_par = ?,
                        date_enregistrement = ?,
                        notes = ?,
                        last_modified_at = ?,
                        last_modified_by = ?
                        WHERE shop_id = ? AND date_cloture = ?";
                
                $stmt = $pdo->prepare($sql);
                $stmt->execute([
                    $entity['solde_frais_anterieur'] ?? 0,
                    $entity['solde_saisi_cash'] ?? 0,
                    $entity['solde_saisi_airtel_money'] ?? 0,
                    $entity['solde_saisi_mpesa'] ?? 0,
                    $entity['solde_saisi_orange_money'] ?? 0,
                    $entity['solde_saisi_total'] ?? 0,
                    $entity['solde_calcule_cash'] ?? 0,
                    $entity['solde_calcule_airtel_money'] ?? 0,
                    $entity['solde_calcule_mpesa'] ?? 0,
                    $entity['solde_calcule_orange_money'] ?? 0,
                    $entity['solde_calcule_total'] ?? 0,
                    $entity['ecart_cash'] ?? 0,
                    $entity['ecart_airtel_money'] ?? 0,
                    $entity['ecart_mpesa'] ?? 0,
                    $entity['ecart_orange_money'] ?? 0,
                    $entity['ecart_total'] ?? 0,
                    $entity['cloture_par'],
                    date('Y-m-d H:i:s', strtotime($entity['date_enregistrement'])),
                    $entity['notes'] ?? null,
                    $timestamp,
                    $userId,
                    $entity['shop_id'],
                    date('Y-m-d', strtotime($entity['date_cloture']))
                ]);
                
                $updated++;
            } else {
                // INSERT avec l'ID de l'app pour éviter les erreurs de contrainte foreign key
                $sql = "REPLACE INTO cloture_caisse 
                        (id, shop_id, date_cloture, solde_frais_anterieur,
                         solde_saisi_cash, solde_saisi_airtel_money, solde_saisi_mpesa, solde_saisi_orange_money, solde_saisi_total,
                         solde_calcule_cash, solde_calcule_airtel_money, solde_calcule_mpesa, solde_calcule_orange_money, solde_calcule_total,
                         ecart_cash, ecart_airtel_money, ecart_mpesa, ecart_orange_money, ecart_total,
                         cloture_par, date_enregistrement, notes, 
                         created_at, last_modified_at, last_modified_by, is_synced, synced_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)";
                
                $stmt = $pdo->prepare($sql);
                $stmt->execute([
                    $entity['id'] ?? null,  // Utiliser l'ID de l'app si fourni
                    $entity['shop_id'],
                    date('Y-m-d', strtotime($entity['date_cloture'])),
                    $entity['solde_frais_anterieur'] ?? 0,
                    $entity['solde_saisi_cash'] ?? 0,
                    $entity['solde_saisi_airtel_money'] ?? 0,
                    $entity['solde_saisi_mpesa'] ?? 0,
                    $entity['solde_saisi_orange_money'] ?? 0,
                    $entity['solde_saisi_total'] ?? 0,
                    $entity['solde_calcule_cash'] ?? 0,
                    $entity['solde_calcule_airtel_money'] ?? 0,
                    $entity['solde_calcule_mpesa'] ?? 0,
                    $entity['solde_calcule_orange_money'] ?? 0,
                    $entity['solde_calcule_total'] ?? 0,
                    $entity['ecart_cash'] ?? 0,
                    $entity['ecart_airtel_money'] ?? 0,
                    $entity['ecart_mpesa'] ?? 0,
                    $entity['ecart_orange_money'] ?? 0,
                    $entity['ecart_total'] ?? 0,
                    $entity['cloture_par'],
                    date('Y-m-d H:i:s', strtotime($entity['date_enregistrement'])),
                    $entity['notes'] ?? null,
                    date('Y-m-d H:i:s'),
                    $timestamp,
                    $userId,
                    date('Y-m-d H:i:s')
                ]);
                
                $uploaded++;
            }
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['shop_id'] . '_' . $entity['date_cloture'],
                'error' => $e->getMessage()
            ];
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
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
