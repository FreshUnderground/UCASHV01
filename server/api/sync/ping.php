<?php
// En-têtes CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization, X-Requested-With');
header('Content-Type: application/json');

// Gérer OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Réponse simple pour tester la connexion
echo json_encode([
    'success' => true,
    'message' => 'Serveur accessible',
    'timestamp' => date('c'),
    'server' => $_SERVER['SERVER_NAME'] ?? 'unknown'
]);
?>
