<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../../classes/Database.php';
require_once __DIR__ . '/../../../config/database.php';

try {
    $database = Database::getInstance();
    $pdo = $database->getConnection();
    
    // Lire les données JSON du corps de la requête
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || !isset($input['credits']) || !is_array($input['credits'])) {
        throw new Exception('Données invalides: tableau de crédits requis');
    }
    
    $credits = $input['credits'];
    $results = [];
    
    $pdo->beginTransaction();
    
    foreach ($credits as $creditData) {
        try {
            // Valider les champs requis
            $requiredFields = ['reference', 'montant_credit', 'beneficiaire_nom', 'sim_numero', 'shop_id', 'agent_id', 'date_sortie'];
            foreach ($requiredFields as $field) {
                if (!isset($creditData[$field]) || $creditData[$field] === '') {
                    throw new Exception("Champ requis manquant: $field");
                }
            }
            
            // Vérifier si le crédit existe déjà
            $checkStmt = $pdo->prepare("SELECT id, last_modified_at FROM credit_virtuel WHERE reference = ?");
            $checkStmt->execute([$creditData['reference']]);
            $existing = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing) {
                // Mise à jour si la version locale est plus récente
                $localModified = new DateTime($creditData['last_modified_at'] ?? 'now');
                $serverModified = new DateTime($existing['last_modified_at']);
                
                if ($localModified > $serverModified) {
                    $updateSql = "UPDATE credit_virtuel SET 
                        montant_credit = ?, devise = ?, beneficiaire_nom = ?, beneficiaire_telephone = ?,
                        beneficiaire_adresse = ?, type_beneficiaire = ?, sim_numero = ?, shop_id = ?,
                        shop_designation = ?, agent_id = ?, agent_username = ?, statut = ?,
                        date_sortie = ?, date_paiement = ?, date_echeance = ?, notes = ?,
                        montant_paye = ?, mode_paiement = ?, reference_paiement = ?,
                        last_modified_at = ?, last_modified_by = ?, is_synced = ?
                        WHERE id = ?";
                    
                    $updateStmt = $pdo->prepare($updateSql);
                    $updateStmt->execute([
                        $creditData['montant_credit'],
                        $creditData['devise'] ?? 'USD',
                        $creditData['beneficiaire_nom'],
                        $creditData['beneficiaire_telephone'] ?? null,
                        $creditData['beneficiaire_adresse'] ?? null,
                        $creditData['type_beneficiaire'] ?? 'shop',
                        $creditData['sim_numero'],
                        $creditData['shop_id'],
                        $creditData['shop_designation'] ?? null,
                        $creditData['agent_id'],
                        $creditData['agent_username'] ?? null,
                        $creditData['statut'] ?? 'accorde',
                        $creditData['date_sortie'],
                        $creditData['date_paiement'] ?? null,
                        $creditData['date_echeance'] ?? null,
                        $creditData['notes'] ?? null,
                        $creditData['montant_paye'] ?? 0.0,
                        $creditData['mode_paiement'] ?? null,
                        $creditData['reference_paiement'] ?? null,
                        $creditData['last_modified_at'] ?? date('Y-m-d H:i:s'),
                        $creditData['last_modified_by'] ?? null,
                        1, // is_synced = true
                        $existing['id']
                    ]);
                    
                    $results[] = [
                        'reference' => $creditData['reference'],
                        'action' => 'updated',
                        'id' => $existing['id']
                    ];
                } else {
                    $results[] = [
                        'reference' => $creditData['reference'],
                        'action' => 'skipped',
                        'reason' => 'Version serveur plus récente'
                    ];
                }
            } else {
                // Insertion d'un nouveau crédit
                $insertSql = "INSERT INTO credit_virtuel (
                    reference, montant_credit, devise, beneficiaire_nom, beneficiaire_telephone,
                    beneficiaire_adresse, type_beneficiaire, sim_numero, shop_id, shop_designation,
                    agent_id, agent_username, statut, date_sortie, date_paiement, date_echeance,
                    notes, montant_paye, mode_paiement, reference_paiement,
                    last_modified_at, last_modified_by, is_synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                
                $insertStmt = $pdo->prepare($insertSql);
                $insertStmt->execute([
                    $creditData['reference'],
                    $creditData['montant_credit'],
                    $creditData['devise'] ?? 'USD',
                    $creditData['beneficiaire_nom'],
                    $creditData['beneficiaire_telephone'] ?? null,
                    $creditData['beneficiaire_adresse'] ?? null,
                    $creditData['type_beneficiaire'] ?? 'shop',
                    $creditData['sim_numero'],
                    $creditData['shop_id'],
                    $creditData['shop_designation'] ?? null,
                    $creditData['agent_id'],
                    $creditData['agent_username'] ?? null,
                    $creditData['statut'] ?? 'accorde',
                    $creditData['date_sortie'],
                    $creditData['date_paiement'] ?? null,
                    $creditData['date_echeance'] ?? null,
                    $creditData['notes'] ?? null,
                    $creditData['montant_paye'] ?? 0.0,
                    $creditData['mode_paiement'] ?? null,
                    $creditData['reference_paiement'] ?? null,
                    $creditData['last_modified_at'] ?? date('Y-m-d H:i:s'),
                    $creditData['last_modified_by'] ?? null,
                    1 // is_synced = true
                ]);
                
                $newId = $pdo->lastInsertId();
                $results[] = [
                    'reference' => $creditData['reference'],
                    'action' => 'inserted',
                    'id' => $newId
                ];
            }
            
        } catch (Exception $e) {
            $results[] = [
                'reference' => $creditData['reference'] ?? 'unknown',
                'action' => 'error',
                'error' => $e->getMessage()
            ];
        }
    }
    
    $pdo->commit();
    
    echo json_encode([
        'success' => true,
        'results' => $results,
        'processed' => count($credits),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    if (isset($pdo)) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>
