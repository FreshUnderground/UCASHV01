<?php
// Script de test pour vérifier les API de synchronisation du personnel
// À exécuter directement dans le navigateur pour tester les endpoints

header('Content-Type: application/json; charset=utf-8');

echo "<h1>Test des API Personnel - UCASH</h1>";
echo "<pre>";

// Configuration
$baseUrl = 'https://mahanaimeservice.investee-group.com/server/api/sync/personnel';

// Test 1: Vérifier l'endpoint changes.php
echo "=== TEST 1: GET changes.php ===\n";
$url = $baseUrl . '/changes.php';
echo "URL: $url\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
if ($error) {
    echo "CURL Error: $error\n";
} else {
    echo "Response: " . substr($response, 0, 500) . "...\n";
    $data = json_decode($response, true);
    if ($data) {
        echo "Success: " . ($data['success'] ? 'true' : 'false') . "\n";
        echo "Count: " . ($data['count'] ?? 'N/A') . "\n";
    }
}

echo "\n";

// Test 2: Vérifier l'endpoint upload.php avec données de test
echo "=== TEST 2: POST upload.php ===\n";
$url = $baseUrl . '/upload.php';
echo "URL: $url\n";

$testData = [
    'entities' => [
        [
            '_table' => 'personnel',
            'matricule' => 'TEST_API_001',
            'nom' => 'Test',
            'prenom' => 'API',
            'telephone' => '+243999999999',
            'poste' => 'Agent Test API',
            'date_embauche' => date('Y-m-d'),
            'salaire_base' => 100.00,
            'is_synced' => false,
            'created_at' => date('Y-m-d H:i:s'),
            'last_modified_at' => date('Y-m-d H:i:s')
        ]
    ],
    'user_id' => 'test_api'
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($testData));
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
if ($error) {
    echo "CURL Error: $error\n";
} else {
    echo "Response: " . substr($response, 0, 500) . "...\n";
    $data = json_decode($response, true);
    if ($data) {
        echo "Success: " . ($data['success'] ? 'true' : 'false') . "\n";
        echo "Uploaded: " . ($data['uploaded_count'] ?? 'N/A') . "\n";
        echo "Updated: " . ($data['updated_count'] ?? 'N/A') . "\n";
    }
}

echo "\n";

// Test 3: Vérifier la connexion à la base de données
echo "=== TEST 3: Connexion Base de Données ===\n";
try {
    require_once __DIR__ . '/server/config/database.php';
    echo "✅ Connexion DB réussie\n";
    
    // Test simple query
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM personnel");
    $result = $stmt->fetch();
    echo "Personnel en DB: " . $result['count'] . "\n";
    
} catch (Exception $e) {
    echo "❌ Erreur DB: " . $e->getMessage() . "\n";
}

echo "\n";

// Test 4: Vérifier les permissions de fichiers
echo "=== TEST 4: Permissions Fichiers ===\n";
$files = [
    __DIR__ . '/server/api/sync/personnel/upload.php',
    __DIR__ . '/server/api/sync/personnel/changes.php',
    __DIR__ . '/server/api/sync/personnel/delete.php',
    __DIR__ . '/server/config/database.php'
];

foreach ($files as $file) {
    if (file_exists($file)) {
        echo "✅ " . basename($file) . " existe\n";
        if (is_readable($file)) {
            echo "   ✅ Lisible\n";
        } else {
            echo "   ❌ Non lisible\n";
        }
    } else {
        echo "❌ " . basename($file) . " manquant\n";
    }
}

echo "</pre>";
?>
