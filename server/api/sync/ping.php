<?php
/**
 * Endpoint de test de connectivité pour la synchronisation
 * Retourne un simple message de confirmation que le serveur est accessible
 */

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
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Méthode non autorisée. Utilisez GET.'
    ]);
    exit();
}

// Vérifier la connexion à la base de données (optionnel)
$dbStatus = 'unknown';
try {
    require_once __DIR__ . '/../../config/database.php';
    if (isset($pdo) && $pdo instanceof PDO) {
        $stmt = $pdo->query('SELECT 1');
        $dbStatus = 'connected';
    }
} catch (Exception $e) {
    $dbStatus = 'error: ' . $e->getMessage();
}

// Réponse de succès
http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'UCASH Sync Server - Opérationnel',
    'timestamp' => date('c'),
    'server_time' => date('Y-m-d H:i:s'),
    'database' => $dbStatus,
    'version' => '1.0.0'
]);
