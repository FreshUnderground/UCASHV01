<?php
/**
 * Configuration CORS pour Flutter Web
 * À inclure au début de chaque fichier API PHP
 */

// Headers CORS pour Flutter Web
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept");
header("Access-Control-Max-Age: 3600");

// Gestion des requêtes OPTIONS (preflight)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Configuration pour éviter les erreurs de cache
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");

// Configuration JSON
header("Content-Type: application/json; charset=UTF-8");

// Fonction pour répondre en JSON avec gestion d'erreurs
function sendJsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit();
}

// Fonction pour gérer les erreurs HTTP
function sendErrorResponse($message, $statusCode = 400, $errorCode = null) {
    $response = [
        'success' => false,
        'error' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    if ($errorCode) {
        $response['error_code'] = $errorCode;
    }
    
    sendJsonResponse($response, $statusCode);
}

// Fonction pour valider les données POST
function validatePostData($requiredFields = []) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        sendErrorResponse('Invalid JSON format', 400, 'INVALID_JSON');
    }
    
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            sendErrorResponse("Missing required field: $field", 400, 'MISSING_FIELD');
        }
    }
    
    return $input;
}

// Configuration de la timezone
date_default_timezone_set('Africa/Kinshasa');

// Démarrage de session si nécessaire
if (session_status() == PHP_SESSION_NONE) {
    session_start();
}
?>
