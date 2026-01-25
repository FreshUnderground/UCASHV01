<?php
/**
 * Script de test pour l'upload de commissions
 * Teste si l'API upload.php fonctionne correctement
 */

header('Content-Type: application/json');

// Test data - simule une commission de l'app
$testCommission = [
    'id' => time(), // ID timestamp comme l'app
    'type' => 'SORTANT',
    'taux' => 2.5,
    'description' => 'Test commission depuis script PHP',
    'shop_id' => null,
    'shop_source_id' => null,
    'shop_destination_id' => null,
    'is_active' => 1,
    'is_synced' => 0,
    'last_modified_at' => date('Y-m-d H:i:s'),
    'last_modified_by' => 'TEST_SCRIPT',
    'synced_at' => date('c'),
];

// Préparer les données comme l'app les envoie
$postData = [
    'entities' => [$testCommission],
    'user_id' => 'test_user',
    'timestamp' => date('c'),
];

echo "=== TEST UPLOAD COMMISSION ===\n\n";
echo "Données à envoyer:\n";
echo json_encode($postData, JSON_PRETTY_PRINT) . "\n\n";

// Simuler la requête POST vers upload.php
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://safdal.investee-group.com/server/api/sync/commissions/upload.php');
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($postData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json',
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "Réponse HTTP: $httpCode\n\n";
echo "Réponse du serveur:\n";
echo json_encode(json_decode($response), JSON_PRETTY_PRINT) . "\n\n";

// Vérifier la base de données
require_once __DIR__ . '/../../../config/database.php';

echo "=== VÉRIFICATION BASE DE DONNÉES ===\n\n";

try {
    $stmt = $pdo->query("SELECT * FROM commissions ORDER BY id DESC LIMIT 5");
    $commissions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Dernières commissions dans la DB:\n";
    foreach ($commissions as $comm) {
        echo "ID: {$comm['id']}, Type: {$comm['type']}, Taux: {$comm['taux']}%, Description: {$comm['description']}\n";
    }
} catch (Exception $e) {
    echo "Erreur DB: " . $e->getMessage() . "\n";
}
