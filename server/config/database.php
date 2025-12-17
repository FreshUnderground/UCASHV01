<?php
// Configuration de la base de données pour UCASH
// Ce fichier doit être configuré selon votre environnement local

// Paramètres de connexion
define('DB_HOST', '91.216.107.185');
define('DB_NAME', 'inves2504808_1n6a7b');
define('DB_USER', 'inves2504808');
define('DB_PASS', '31nzzasdnh');

try {
    // Création de la connexion PDO
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
} catch (PDOException $e) {
    // Log the error for debugging
    error_log("Database connection error: " . $e->getMessage());
    
    // Return a proper JSON error response
    if (isset($_SERVER['HTTP_HOST'])) {
        // Mode web
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'message' => 'Erreur de connexion à la base de données',
            'error_details' => $e->getMessage(),
            'error_code' => $e->getCode(),
            'db_config' => [
                'host' => DB_HOST,
                'database' => DB_NAME,
                'user' => DB_USER,
            ],
            'timestamp' => date('c')
        ]);
    } else {
        // Mode CLI
        echo "Erreur de connexion à la base de données: " . $e->getMessage() . "\n";
    }
    exit(1);
}
?>