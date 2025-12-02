<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Access-Control-Max-Age: 86400');

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Vérifier la méthode HTTP
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Méthode non autorisée']);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Lire les données POST
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!isset($data['entities']) || !is_array($data['entities'])) {
        throw new Exception('Données invalides: entities requis');
    }
    
    $entities = $data['entities'];
    $userId = $data['user_id'] ?? 'unknown';
    $uploadedCount = 0;
    $updatedCount = 0;
    $errors = [];
    
    // Début de transaction
    $pdo->beginTransaction();
    
    foreach ($entities as $entity) {
        try {
            // Vérifier si le dépôt client existe déjà
            $checkStmt = $pdo->prepare("
                SELECT id FROM depot_clients 
                WHERE id = :id
            ");
            $checkStmt->execute([':id' => $entity['id'] ?? 0]);
            $exists = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($exists) {
                // Mise à jour du dépôt existant
                $updateStmt = $pdo->prepare("
                    UPDATE depot_clients SET
                        shop_id = :shop_id,
                        sim_numero = :sim_numero,
                        montant = :montant,
                        telephone_client = :telephone_client,
                        date_depot = :date_depot,
                        user_id = :user_id
                    WHERE id = :id
                ");
                
                $updateStmt->execute([
                    ':id' => $entity['id'],
                    ':shop_id' => $entity['shop_id'] ?? 1,
                    ':sim_numero' => $entity['sim_numero'] ?? '',
                    ':montant' => $entity['montant'] ?? 0,
                    ':telephone_client' => $entity['telephone_client'] ?? '',
                    ':date_depot' => $entity['date_depot'] ?? date('Y-m-d H:i:s'),
                    ':user_id' => $entity['user_id'] ?? $userId
                ]);
                
                $updatedCount++;
            } else {
                // Insertion d'un nouveau dépôt client
                $insertStmt = $pdo->prepare("
                    INSERT INTO depot_clients (
                        id, shop_id, sim_numero, montant, telephone_client, date_depot, user_id
                    ) VALUES (
                        :id, :shop_id, :sim_numero, :montant, :telephone_client, :date_depot, :user_id
                    )
                ");
                
                $insertStmt->execute([
                    ':id' => $entity['id'] ?? null,
                    ':shop_id' => $entity['shop_id'] ?? 1,
                    ':sim_numero' => $entity['sim_numero'] ?? '',
                    ':montant' => $entity['montant'] ?? 0,
                    ':telephone_client' => $entity['telephone_client'] ?? '',
                    ':date_depot' => $entity['date_depot'] ?? date('Y-m-d H:i:s'),
                    ':user_id' => $entity['user_id'] ?? $userId
                ]);
                
                $uploadedCount++;
            }
        } catch (Exception $e) {
            $errors[] = [
                'entity_id' => $entity['id'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    // Commit de la transaction
    $pdo->commit();
    
    $response = [
        'success' => true,
        'message' => 'Synchronisation réussie',
        'uploaded' => $uploadedCount,
        'updated' => $updatedCount,
        'total' => $uploadedCount + $updatedCount,
        'errors' => $errors,
        'timestamp' => date('c')
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Erreur serveur: ' . $e->getMessage(),
        'timestamp' => date('c')
    ]);
}
?>
