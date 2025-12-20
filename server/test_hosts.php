<?php
// Configuration alternative - Essayer différents hôtes MySQL
// À utiliser si 'localhost' ne fonctionne pas

// Paramètres de base
$dbName = 'inves2504808_1n6a7b';
$dbUser = 'inves2504808';
$dbPass = '31nzzasdnh';

// Essayer différents hôtes dans l'ordre
$hostsToTry = [
    'localhost',
    '127.0.0.1',
    'localhost:/tmp/mysql.sock',
    'localhost:3306',
];

$pdo = null;
$successfulHost = null;

foreach ($hostsToTry as $host) {
    try {
        $pdo = new PDO(
            "mysql:host={$host};dbname={$dbName};charset=utf8mb4",
            $dbUser,
            $dbPass,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        $successfulHost = $host;
        break; // Connexion réussie, sortir de la boucle
    } catch (PDOException $e) {
        // Continuer avec l'hôte suivant
        continue;
    }
}

if ($pdo === null) {
    // Aucun hôte n'a fonctionné
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Impossible de se connecter à MySQL avec aucun des hôtes testés',
        'hosts_tried' => $hostsToTry,
        'timestamp' => date('c')
    ]);
    exit(1);
}

// Connexion réussie
echo json_encode([
    'success' => true,
    'message' => 'Connexion réussie!',
    'successful_host' => $successfulHost,
    'timestamp' => date('c')
]);
?>
