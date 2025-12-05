<?php
/**
 * API Endpoint: Upload Admins
 * Permet de créer/mettre à jour les administrateurs
 * Maximum 2 administrateurs autorisés
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['admins']) || !is_array($input['admins'])) {
        throw new Exception('Format de données invalide');
    }
    
    $admins = $input['admins'];
    $userId = $input['user_id'] ?? 'system';
    
    // Vérifier qu'on ne dépasse pas 2 admins
    if (count($admins) > 2) {
        throw new Exception('Maximum 2 administrateurs autorisés');
    }
    
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    $db->beginTransaction();
    
    $created = 0;
    $updated = 0;
    $errors = [];
    
    foreach ($admins as $admin) {
        try {
            // Vérifier le nombre actuel d'admins avant l'insertion
            $countStmt = $db->query("SELECT COUNT(*) FROM users WHERE role IN ('ADMIN', 'admin')");
            $currentCount = $countStmt->fetchColumn();
            
            // Vérifier si l'admin existe déjà
            $checkStmt = $db->prepare("SELECT id FROM users WHERE username = :username");
            $checkStmt->execute([':username' => $admin['username']]);
            $existingAdmin = $checkStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existingAdmin) {
                // UPDATE
                $sql = "UPDATE users SET 
                           password = :password,
                           role = :role,
                           nom = :nom,
                           prenom = :prenom,
                           email = :email,
                           telephone = :telephone,
                           is_active = :is_active,
                           updated_at = NOW()
                       WHERE username = :username";
                
                $stmt = $db->prepare($sql);
                $stmt->execute([
                    ':username' => $admin['username'],
                    ':password' => $admin['password'],
                    ':role' => $admin['role'] ?? 'ADMIN',
                    ':nom' => $admin['nom'] ?? null,
                    ':prenom' => $admin['prenom'] ?? null,
                    ':email' => $admin['email'] ?? null,
                    ':telephone' => $admin['telephone'] ?? null,
                    ':is_active' => isset($admin['is_active']) ? (int)$admin['is_active'] : 1
                ]);
                
                $updated++;
            } else {
                // INSERT - vérifier le quota
                if ($currentCount >= 2) {
                    throw new Exception('Maximum de 2 administrateurs atteint. Impossible d\'en créer plus.');
                }
                
                $sql = "INSERT INTO users 
                           (username, password, role, nom, prenom, email, telephone, is_active, created_at)
                       VALUES 
                           (:username, :password, :role, :nom, :prenom, :email, :telephone, :is_active, NOW())";
                
                $stmt = $db->prepare($sql);
                $stmt->execute([
                    ':username' => $admin['username'],
                    ':password' => $admin['password'],
                    ':role' => $admin['role'] ?? 'ADMIN',
                    ':nom' => $admin['nom'] ?? null,
                    ':prenom' => $admin['prenom'] ?? null,
                    ':email' => $admin['email'] ?? null,
                    ':telephone' => $admin['telephone'] ?? null,
                    ':is_active' => isset($admin['is_active']) ? (int)$admin['is_active'] : 1
                ]);
                
                $created++;
            }
            
        } catch (Exception $e) {
            $errors[] = [
                'username' => $admin['username'] ?? 'unknown',
                'error' => $e->getMessage()
            ];
        }
    }
    
    $db->commit();
    
    // Récupérer tous les admins après la synchronisation
    $stmt = $db->query("SELECT 
                            id, username, password, role, nom, prenom, email, telephone, 
                            is_active, created_at, updated_at 
                         FROM users 
                         WHERE role IN ('ADMIN', 'admin')
                         ORDER BY id ASC
                         LIMIT 2");
    $allAdmins = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'message' => "Synchronisation réussie",
        'stats' => [
            'created' => $created,
            'updated' => $updated,
            'total' => count($allAdmins),
            'max' => 2,
            'errors' => count($errors)
        ],
        'admins' => $allAdmins,
        'errors' => $errors,
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
