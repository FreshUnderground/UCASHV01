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
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Vérifier les champs requis
            if (!isset($entity['shop_id']) || !isset($entity['date_reconciliation'])) {
                throw new Exception('Champs requis manquants');
            }
            
            // Vérifier si la réconciliation existe déjà
            if (isset($entity['id'])) {
                $checkStmt = $pdo->prepare("SELECT id FROM reconciliations WHERE id = ?");
                $checkStmt->execute([$entity['id']]);
                $existing = $checkStmt->fetch();
                
                if ($existing) {
                    // Mise à jour
                    $sql = "UPDATE reconciliations SET
                        shop_id = :shop_id,
                        date_reconciliation = :date_reconciliation,
                        periode = :periode,
                        capital_systeme_cash = :capital_systeme_cash,
                        capital_systeme_airtel = :capital_systeme_airtel,
                        capital_systeme_mpesa = :capital_systeme_mpesa,
                        capital_systeme_orange = :capital_systeme_orange,
                        capital_systeme_total = :capital_systeme_total,
                        capital_reel_cash = :capital_reel_cash,
                        capital_reel_airtel = :capital_reel_airtel,
                        capital_reel_mpesa = :capital_reel_mpesa,
                        capital_reel_orange = :capital_reel_orange,
                        capital_reel_total = :capital_reel_total,
                        statut = :statut,
                        notes = :notes,
                        justification = :justification,
                        devise_secondaire = :devise_secondaire,
                        capital_systeme_devise2 = :capital_systeme_devise2,
                        capital_reel_devise2 = :capital_reel_devise2,
                        action_corrective_requise = :action_corrective_requise,
                        action_corrective_prise = :action_corrective_prise,
                        verified_by = :verified_by,
                        verified_at = :verified_at,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE id = :id";
                } else {
                    // Insertion
                    $sql = "INSERT INTO reconciliations (
                        id, shop_id, date_reconciliation, periode,
                        capital_systeme_cash, capital_systeme_airtel, capital_systeme_mpesa, capital_systeme_orange, capital_systeme_total,
                        capital_reel_cash, capital_reel_airtel, capital_reel_mpesa, capital_reel_orange, capital_reel_total,
                        statut, notes, justification,
                        devise_secondaire, capital_systeme_devise2, capital_reel_devise2,
                        action_corrective_requise, action_corrective_prise,
                        created_by, created_at, verified_by, verified_at,
                        last_modified_at, last_modified_by, is_synced, synced_at
                    ) VALUES (
                        :id, :shop_id, :date_reconciliation, :periode,
                        :capital_systeme_cash, :capital_systeme_airtel, :capital_systeme_mpesa, :capital_systeme_orange, :capital_systeme_total,
                        :capital_reel_cash, :capital_reel_airtel, :capital_reel_mpesa, :capital_reel_orange, :capital_reel_total,
                        :statut, :notes, :justification,
                        :devise_secondaire, :capital_systeme_devise2, :capital_reel_devise2,
                        :action_corrective_requise, :action_corrective_prise,
                        :created_by, :created_at, :verified_by, :verified_at,
                        :last_modified_at, :last_modified_by, 1, NOW()
                    )";
                }
            } else {
                // Insertion sans ID (auto-increment)
                $sql = "INSERT INTO reconciliations (
                    shop_id, date_reconciliation, periode,
                    capital_systeme_cash, capital_systeme_airtel, capital_systeme_mpesa, capital_systeme_orange, capital_systeme_total,
                    capital_reel_cash, capital_reel_airtel, capital_reel_mpesa, capital_reel_orange, capital_reel_total,
                    statut, notes, justification,
                    devise_secondaire, capital_systeme_devise2, capital_reel_devise2,
                    action_corrective_requise, action_corrective_prise,
                    created_by, created_at, verified_by, verified_at,
                    last_modified_at, last_modified_by, is_synced, synced_at
                ) VALUES (
                    :shop_id, :date_reconciliation, :periode,
                    :capital_systeme_cash, :capital_systeme_airtel, :capital_systeme_mpesa, :capital_systeme_orange, :capital_systeme_total,
                    :capital_reel_cash, :capital_reel_airtel, :capital_reel_mpesa, :capital_reel_orange, :capital_reel_total,
                    :statut, :notes, :justification,
                    :devise_secondaire, :capital_systeme_devise2, :capital_reel_devise2,
                    :action_corrective_requise, :action_corrective_prise,
                    :created_by, :created_at, :verified_by, :verified_at,
                    :last_modified_at, :last_modified_by, 1, NOW()
                )";
            }
            
            $stmt = $pdo->prepare($sql);
            $params = [
                ':shop_id' => $entity['shop_id'],
                ':date_reconciliation' => $entity['date_reconciliation'],
                ':periode' => $entity['periode'] ?? 'DAILY',
                ':capital_systeme_cash' => $entity['capital_systeme_cash'] ?? 0,
                ':capital_systeme_airtel' => $entity['capital_systeme_airtel'] ?? 0,
                ':capital_systeme_mpesa' => $entity['capital_systeme_mpesa'] ?? 0,
                ':capital_systeme_orange' => $entity['capital_systeme_orange'] ?? 0,
                ':capital_systeme_total' => $entity['capital_systeme_total'] ?? 0,
                ':capital_reel_cash' => $entity['capital_reel_cash'] ?? 0,
                ':capital_reel_airtel' => $entity['capital_reel_airtel'] ?? 0,
                ':capital_reel_mpesa' => $entity['capital_reel_mpesa'] ?? 0,
                ':capital_reel_orange' => $entity['capital_reel_orange'] ?? 0,
                ':capital_reel_total' => $entity['capital_reel_total'] ?? 0,
                ':statut' => $entity['statut'] ?? 'EN_COURS',
                ':notes' => $entity['notes'] ?? null,
                ':justification' => $entity['justification'] ?? null,
                ':devise_secondaire' => $entity['devise_secondaire'] ?? null,
                ':capital_systeme_devise2' => $entity['capital_systeme_devise2'] ?? null,
                ':capital_reel_devise2' => $entity['capital_reel_devise2'] ?? null,
                ':action_corrective_requise' => isset($entity['action_corrective_requise']) ? ($entity['action_corrective_requise'] ? 1 : 0) : 0,
                ':action_corrective_prise' => $entity['action_corrective_prise'] ?? null,
                ':created_by' => $entity['created_by'] ?? null,
                ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s'),
                ':verified_by' => $entity['verified_by'] ?? null,
                ':verified_at' => $entity['verified_at'] ?? null,
                ':last_modified_at' => $timestamp,
                ':last_modified_by' => $userId,
            ];
            
            if (isset($entity['id']) && isset($existing)) {
                $params[':id'] = $entity['id'];
            } elseif (isset($entity['id'])) {
                $params[':id'] = $entity['id'];
            }
            
            $stmt->execute($params);
            $uploaded++;
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload terminé',
        'uploaded' => $uploaded,
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
