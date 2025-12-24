<?php
// Activer la capture d'erreurs pour retourner du JSON
error_reporting(E_ALL);
ini_set('display_errors', 0); // Ne PAS afficher les erreurs en HTML
ini_set('log_errors', 1);

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

require_once __DIR__ . '/../../../config/database.php';

try {
    // Log de débogage
    error_log("🔺 Triangular upload - Début traitement");
    
    // Récupération des données JSON
    $input = file_get_contents('php://input');
    error_log("🔺 Input reçu: " . substr($input, 0, 500) . "...");
    
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['entities'])) {
        error_log("🔺 Erreur: Données JSON invalides");
        throw new Exception('Données JSON invalides');
    }
    
    error_log("🔺 Entities reçues: " . count($data['entities']));
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('c');
    $uploaded = 0;
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Vérifier les champs requis
            if (!isset($entity['shop_debtor_id']) || 
                !isset($entity['shop_intermediary_id']) || 
                !isset($entity['shop_creditor_id']) ||
                !isset($entity['montant']) ||
                !isset($entity['date_reglement'])) {
                throw new Exception('Champs requis manquants');
            }
            
            // Vérifier si le règlement existe déjà par référence
            $checkStmt = $pdo->prepare("SELECT reference FROM triangular_debt_settlements WHERE reference = ?");
            $checkStmt->execute([$entity['reference']]);
            $existing = $checkStmt->fetch();
                
                if ($existing) {
                    // Mise à jour
                    $sql = "UPDATE triangular_debt_settlements SET
                        reference = :reference,
                        shop_debtor_id = :shop_debtor_id,
                        shop_debtor_designation = :shop_debtor_designation,
                        shop_intermediary_id = :shop_intermediary_id,
                        shop_intermediary_designation = :shop_intermediary_designation,
                        shop_creditor_id = :shop_creditor_id,
                        shop_creditor_designation = :shop_creditor_designation,
                        montant = :montant,
                        devise = :devise,
                        date_reglement = :date_reglement,
                        mode_paiement = :mode_paiement,
                        notes = :notes,
                        agent_id = :agent_id,
                        agent_username = :agent_username,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by,
                        is_synced = 1,
                        synced_at = NOW()
                    WHERE reference = :reference";
                } else {
                    // Insertion
                    $sql = "INSERT INTO triangular_debt_settlements (
                        reference,
                        shop_debtor_id, shop_debtor_designation,
                        shop_intermediary_id, shop_intermediary_designation,
                        shop_creditor_id, shop_creditor_designation,
                        montant, devise, date_reglement,
                        mode_paiement, notes,
                        agent_id, agent_username,
                        created_at, last_modified_at, last_modified_by,
                        is_synced, synced_at
                    ) VALUES (
                        :reference,
                        :shop_debtor_id, :shop_debtor_designation,
                        :shop_intermediary_id, :shop_intermediary_designation,
                        :shop_creditor_id, :shop_creditor_designation,
                        :montant, :devise, :date_reglement,
                        :mode_paiement, :notes,
                        :agent_id, :agent_username,
                        :created_at, :last_modified_at, :last_modified_by,
                        1, NOW()
                    )";
                }
            
            $stmt = $pdo->prepare($sql);
            $params = [
                ':reference' => $entity['reference'],
                ':shop_debtor_id' => $entity['shop_debtor_id'],
                ':shop_debtor_designation' => $entity['shop_debtor_designation'] ?? null,
                ':shop_intermediary_id' => $entity['shop_intermediary_id'],
                ':shop_intermediary_designation' => $entity['shop_intermediary_designation'] ?? null,
                ':shop_creditor_id' => $entity['shop_creditor_id'],
                ':shop_creditor_designation' => $entity['shop_creditor_designation'] ?? null,
                ':montant' => $entity['montant'],
                ':devise' => $entity['devise'] ?? 'USD',
                ':date_reglement' => $entity['date_reglement'],
                ':mode_paiement' => $entity['mode_paiement'] ?? null,
                ':notes' => $entity['notes'] ?? null,
                ':agent_id' => $entity['agent_id'],
                ':agent_username' => $entity['agent_username'] ?? null,
                ':created_at' => $entity['created_at'] ?? date('Y-m-d H:i:s'),
                ':last_modified_at' => $timestamp,
                ':last_modified_by' => $userId,
            ];
            
            // Pas besoin de paramètre :id car on utilise reference comme clé primaire
            
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
