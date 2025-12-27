<?php
// Configuration de la base de données pour UCASH
// Ce fichier utilise maintenant les variables d'environnement sécurisées

// Charger la configuration d'environnement
require_once __DIR__ . '/env.php';

// Les paramètres sont maintenant définis dans env.php

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