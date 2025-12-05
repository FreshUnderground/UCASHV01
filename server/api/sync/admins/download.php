<?php
/**
 * API Endpoint: Download Admins
 * Permet de télécharger les administrateurs depuis le serveur
 * Maximum 2 administrateurs autorisés
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../../../config/database.php';

try {
    // Récupérer les paramètres
    $input = json_decode(file_get_contents('php://input'), true);
    $lastSyncTimestamp = $input['last_sync_timestamp'] ?? null;
    
    // Use the $pdo connection from config/database.php
    $db = $pdo;
    
    // Construire la requête SQL
    $sql = "SELECT 
                id,
                username,
                password,
                role,
                nom,
                prenom,
                email,
                telephone,
                is_active,
                created_at,
                updated_at
            FROM users 
            WHERE role IN ('ADMIN', 'admin')";
    
    $params = [];
    
    // Filtrer par date de modification si fournie
    if ($lastSyncTimestamp) {
        $sql .= " AND (updated_at > :last_sync OR created_at > :last_sync)";
        $params[':last_sync'] = $lastSyncTimestamp;
    }
    
    $sql .= " ORDER BY id ASC LIMIT 2"; // Maximum 2 admins
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    $admins = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formater les données pour Flutter
    $formatted_admins = array_map(function($admin) {
        return [
            'id' => (int)$admin['id'],
            'username' => $admin['username'],
            'password' => $admin['password'],
            'role' => strtoupper($admin['role']),
            'nom' => $admin['nom'],
            'prenom' => $admin['prenom'],
            'email' => $admin['email'],
            'telephone' => $admin['telephone'],
            'shop_id' => null, // Admins n'ont pas de shop
            'is_active' => (bool)$admin['is_active'],
            'created_at' => $admin['created_at'],
            'updated_at' => $admin['updated_at']
        ];
    }, $admins);
    
    // Réponse
    echo json_encode([
        'success' => true,
        'count' => count($formatted_admins),
        'max_admins' => 2,
        'admins' => $formatted_admins,
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Erreur de base de données: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Erreur: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
