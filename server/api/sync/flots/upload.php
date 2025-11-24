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
require_once '../../../classes/Database.php';

// Fonction de conversion de l'enum ModePaiement Flutter vers SQL
function _convertModePaiement($index) {
    // Flutter enum: cash=0, airtelMoney=1, mPesa=2, orangeMoney=3
    // MySQL ENUM: 'cash', 'airtelMoney', 'mPesa', 'orangeMoney'
    $modes = ['cash', 'airtelMoney', 'mPesa', 'orangeMoney'];
    return $modes[$index] ?? 'cash';
}

// Fonction de conversion de l'enum StatutFlot Flutter vers SQL
function _convertStatutFlot($index) {
    // Flutter enum: enRoute=0, servi=1, annule=2
    // MySQL ENUM: 'enRoute', 'servi', 'annule'
    $statuts = ['enRoute', 'servi', 'annule'];
    return $statuts[$index] ?? 'enRoute';
}

try {
    // Récupération des données JSON
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['entities'])) {
        throw new Exception('Données JSON invalides');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $timestamp = $data['timestamp'] ?? date('Y-m-d H:i:s');
    
    $db = Database::getInstance();
    $pdo = $db->getConnection();
    $uploaded = 0;
    $errors = [];
    
    foreach ($entities as $entity) {
        try {
            // Convertir les enums si nécessaire
            if (isset($entity['mode_paiement']) && is_numeric($entity['mode_paiement'])) {
                $entity['mode_paiement'] = _convertModePaiement((int)$entity['mode_paiement']);
            }
            
            if (isset($entity['statut']) && is_numeric($entity['statut'])) {
                $entity['statut'] = _convertStatutFlot((int)$entity['statut']);
            }
            
            // Convertir les dates au format MySQL
            if (isset($entity['date_envoi'])) {
                $entity['date_envoi'] = date('Y-m-d H:i:s', strtotime($entity['date_envoi']));
            }
            
            if (isset($entity['date_reception']) && !empty($entity['date_reception'])) {
                $entity['date_reception'] = date('Y-m-d H:i:s', strtotime($entity['date_reception']));
            } else {
                $entity['date_reception'] = null;
            }
            
            // Métadonnées de synchronisation
            $entity['last_modified_at'] = $timestamp;
            $entity['last_modified_by'] = $userId;
            
            // Vérifier si le flot existe déjà par reference ET date_envoi
            // (car un flot peut être modifié localement de enRoute à servi)
            $checkStmt = $pdo->prepare("
                SELECT id, statut, date_reception 
                FROM flots 
                WHERE reference = ? AND date_envoi = ?
            ");
            $checkStmt->execute([
                $entity['reference'] ?? null,
                $entity['date_envoi']
            ]);
            $exists = $checkStmt->fetch();
            
            if ($exists) {
                // Mise à jour du flot existant (notamment changement enRoute → servi)
                $stmt = $pdo->prepare("
                    UPDATE flots SET
                        shop_source_id = :shop_source_id,
                        shop_destination_id = :shop_destination_id,
                        montant = :montant,
                        devise = :devise,
                        mode_paiement = :mode_paiement,
                        statut = :statut,
                        agent_envoyeur_id = :agent_envoyeur_id,
                        agent_recepteur_id = :agent_recepteur_id,
                        date_envoi = :date_envoi,
                        date_reception = :date_reception,
                        notes = :notes,
                        last_modified_at = :last_modified_at,
                        last_modified_by = :last_modified_by
                    WHERE reference = :reference AND date_envoi = :date_envoi_where
                ");
                
                $stmt->execute([
                    ':shop_source_id' => $entity['shop_source_id'],
                    ':shop_destination_id' => $entity['shop_destination_id'],
                    ':montant' => $entity['montant'],
                    ':devise' => $entity['devise'] ?? 'USD',
                    ':mode_paiement' => $entity['mode_paiement'],
                    ':statut' => $entity['statut'],
                    ':agent_envoyeur_id' => $entity['agent_envoyeur_id'],
                    ':agent_recepteur_id' => $entity['agent_recepteur_id'] ?? null,
                    ':date_envoi' => $entity['date_envoi'],
                    ':date_reception' => $entity['date_reception'],
                    ':notes' => $entity['notes'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'],
                    ':last_modified_by' => $entity['last_modified_by'],
                    ':reference' => $entity['reference'] ?? null,
                    ':date_envoi_where' => $entity['date_envoi']
                ]);
                
                $oldStatut = $exists['statut'];
                $newStatut = $entity['statut'];
                error_log("Flot mis à jour: REF " . $entity['reference'] . " | Statut: $oldStatut → $newStatut | date_reception: " . ($entity['date_reception'] ?? 'NULL'));
            } else {
                // Insertion
                $stmt = $pdo->prepare("
                    INSERT INTO flots (
                        id, shop_source_id, shop_destination_id,
                        montant, devise, mode_paiement, statut,
                        agent_envoyeur_id, agent_recepteur_id,
                        date_envoi, date_reception, reference, notes,
                        created_at, last_modified_at, last_modified_by
                    ) VALUES (
                        :id, :shop_source_id, :shop_destination_id,
                        :montant, :devise, :mode_paiement, :statut,
                        :agent_envoyeur_id, :agent_recepteur_id,
                        :date_envoi, :date_reception, :reference, :notes,
                        NOW(), :last_modified_at, :last_modified_by
                    )
                ");
                
                $stmt->execute([
                    ':id' => $entity['id'] ?? null,
                    ':shop_source_id' => $entity['shop_source_id'],
                    ':shop_destination_id' => $entity['shop_destination_id'],
                    ':montant' => $entity['montant'],
                    ':devise' => $entity['devise'] ?? 'USD',
                    ':mode_paiement' => $entity['mode_paiement'],
                    ':statut' => $entity['statut'],
                    ':agent_envoyeur_id' => $entity['agent_envoyeur_id'],
                    ':agent_recepteur_id' => $entity['agent_recepteur_id'] ?? null,
                    ':date_envoi' => $entity['date_envoi'],
                    ':date_reception' => $entity['date_reception'],
                    ':reference' => $entity['reference'] ?? null,
                    ':notes' => $entity['notes'] ?? null,
                    ':last_modified_at' => $entity['last_modified_at'],
                    ':last_modified_by' => $entity['last_modified_by']
                ]);
                
                error_log("Flot inséré: REF " . $entity['reference'] . " -> ID " . $pdo->lastInsertId());
            }
            
            $uploaded++;
            
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
            error_log("Erreur upload flot: " . $e->getMessage());
        }
    }
    
    $response = [
        'success' => true,
        'message' => 'Upload FLOTs terminé',
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
