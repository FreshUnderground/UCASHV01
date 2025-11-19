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
            // Vérifier si l'entité existe déjà
            $checkStmt = $pdo->prepare("SELECT id FROM document_headers WHERE id = ?");
            $checkStmt->execute([$entity['id']]);
            $exists = $checkStmt->fetch();
            
            if ($exists) {
                // UPDATE
                $sql = "UPDATE document_headers SET 
                        company_name = ?,
                        company_slogan = ?,
                        address = ?,
                        phone = ?,
                        email = ?,
                        website = ?,
                        logo_path = ?,
                        tax_number = ?,
                        registration_number = ?,
                        is_active = ?,
                        updated_at = ?,
                        last_modified_at = ?,
                        last_modified_by = ?
                        WHERE id = ?";
                
                $stmt = $pdo->prepare($sql);
                $stmt->execute([
                    $entity['company_name'],
                    $entity['company_slogan'] ?? null,
                    $entity['address'] ?? null,
                    $entity['phone'] ?? null,
                    $entity['email'] ?? null,
                    $entity['website'] ?? null,
                    $entity['logo_path'] ?? null,
                    $entity['tax_number'] ?? null,
                    $entity['registration_number'] ?? null,
                    isset($entity['is_active']) ? (int)$entity['is_active'] : 1,
                    date('Y-m-d H:i:s'),
                    $timestamp,
                    $userId,
                    $entity['id']
                ]);
                
                $updated++;
            } else {
                // INSERT
                $sql = "INSERT INTO document_headers 
                        (id, company_name, company_slogan, address, phone, email, website, 
                         logo_path, tax_number, registration_number, is_active, 
                         created_at, updated_at, last_modified_at, last_modified_by, is_synced, synced_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)";
                
                $stmt = $pdo->prepare($sql);
                $stmt->execute([
                    $entity['id'],
                    $entity['company_name'],
                    $entity['company_slogan'] ?? null,
                    $entity['address'] ?? null,
                    $entity['phone'] ?? null,
                    $entity['email'] ?? null,
                    $entity['website'] ?? null,
                    $entity['logo_path'] ?? null,
                    $entity['tax_number'] ?? null,
                    $entity['registration_number'] ?? null,
                    isset($entity['is_active']) ? (int)$entity['is_active'] : 1,
                    date('Y-m-d H:i:s'),
                    date('Y-m-d H:i:s'),
                    $timestamp,
                    $userId,
                    date('Y-m-d H:i:s')
                ]);
                
                $uploaded++;
            }
            
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
