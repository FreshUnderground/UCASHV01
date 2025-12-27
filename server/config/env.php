<?php
/**
 * Configuration d'environnement sécurisée pour UCASH
 * Ce fichier contient les variables d'environnement sensibles
 * À ne JAMAIS commiter dans le contrôle de version
 */

// Charger les variables d'environnement depuis un fichier .env si disponible
function loadEnv($path = __DIR__ . '/../.env') {
    if (!file_exists($path)) {
        return false;
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) {
            continue; // Ignorer les commentaires
        }
        
        list($name, $value) = explode('=', $line, 2);
        $name = trim($name);
        $value = trim($value);
        
        if (!array_key_exists($name, $_ENV)) {
            $_ENV[$name] = $value;
        }
    }
    return true;
}

// Charger le fichier .env
loadEnv();

// Configuration de base de données sécurisée
define('DB_HOST', $_ENV['DB_HOST'] ?? '91.216.107.185');
define('DB_NAME', $_ENV['DB_NAME'] ?? 'inves2504808_6oor7p');
define('DB_USER', $_ENV['DB_USER'] ?? 'inves2504808');
define('DB_PASS', $_ENV['DB_PASS'] ?? '31nzzasdnh');

// Configuration API
define('API_VERSION', $_ENV['API_VERSION'] ?? '1.0.0');
define('API_RATE_LIMIT', (int)($_ENV['API_RATE_LIMIT'] ?? 100)); // Requêtes par minute
define('API_MAX_RESULTS', (int)($_ENV['API_MAX_RESULTS'] ?? 500)); // Limite max par requête
define('API_DEFAULT_LIMIT', (int)($_ENV['API_DEFAULT_LIMIT'] ?? 100)); // Limite par défaut

// Configuration JWT (si implémenté)
define('JWT_SECRET', $_ENV['JWT_SECRET'] ?? 'your-secret-key-change-this');
define('JWT_EXPIRY', (int)($_ENV['JWT_EXPIRY'] ?? 3600)); // 1 heure

// Configuration de compression
define('ENABLE_COMPRESSION', $_ENV['ENABLE_COMPRESSION'] ?? 'true');
define('COMPRESSION_LEVEL', (int)($_ENV['COMPRESSION_LEVEL'] ?? 6));

// Mode debug
define('DEBUG_MODE', $_ENV['DEBUG_MODE'] ?? 'false');
define('LOG_LEVEL', $_ENV['LOG_LEVEL'] ?? 'ERROR');

// Validation des variables critiques
if (empty(DB_HOST) || empty(DB_NAME) || empty(DB_USER)) {
    error_log('ERREUR CRITIQUE: Variables d\'environnement de base de données manquantes');
    if (isset($_SERVER['HTTP_HOST'])) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Configuration serveur incomplète'
        ]);
        exit();
    }
}
