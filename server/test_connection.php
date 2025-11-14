<?php
// Script de test de connexion à la base de données
// À supprimer après diagnostic

header('Content-Type: application/json');

// Paramètres de connexion
$dbHost = 'localhost';
$dbName = 'inves2504808_6oor7p';
$dbUser = 'inves2504808';
$dbPass = '31nzzasdnh';

$result = [
    'timestamp' => date('c'),
    'tests' => []
];

// Test 1: Extensions PHP
$result['tests']['php_version'] = PHP_VERSION;
$result['tests']['pdo_available'] = extension_loaded('pdo');
$result['tests']['pdo_mysql_available'] = extension_loaded('pdo_mysql');

// Test 2: Tentative de connexion
try {
    $dsn = "mysql:host={$dbHost};charset=utf8mb4";
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    $result['tests']['connection_to_server'] = 'SUCCESS';
    
    // Test 3: Sélection de la base de données
    try {
        $pdo->exec("USE `{$dbName}`");
        $result['tests']['database_selection'] = 'SUCCESS';
        
        // Test 4: Lister les tables
        $stmt = $pdo->query("SHOW TABLES");
        $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
        $result['tests']['tables_found'] = $tables;
        $result['tests']['tables_count'] = count($tables);
        
        // Test 5: Vérifier la table agents
        if (in_array('agents', $tables)) {
            $stmt = $pdo->query("SELECT COUNT(*) as count FROM agents");
            $count = $stmt->fetch(PDO::FETCH_ASSOC);
            $result['tests']['agents_count'] = $count['count'];
        } else {
            $result['tests']['agents_table'] = 'NOT FOUND - Table agents does not exist';
        }
        
        $result['success'] = true;
        $result['message'] = 'All tests passed';
        
    } catch (PDOException $e) {
        $result['tests']['database_selection'] = 'FAILED';
        $result['tests']['database_error'] = $e->getMessage();
        $result['success'] = false;
        $result['message'] = 'Database selection failed: ' . $e->getMessage();
    }
    
} catch (PDOException $e) {
    $result['tests']['connection_to_server'] = 'FAILED';
    $result['tests']['connection_error'] = $e->getMessage();
    $result['success'] = false;
    $result['message'] = 'MySQL connection failed: ' . $e->getMessage();
}

// Afficher le résultat
echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
