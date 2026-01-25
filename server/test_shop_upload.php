<?php
/**
 * Script de test manuel pour l'upload de shops
 * Usage: Exécuter via navigateur ou CLI pour tester l'API upload
 */

header('Content-Type: application/json; charset=utf-8');

echo "=== TEST UPLOAD SHOP ===\n\n";

// Simuler les données qu'une app Flutter enverrait
$testShop = [
    'id' => time(), // ID unique basé sur timestamp
    'designation' => 'SHOP TEST MANUEL',
    'localisation' => 'Butembo Centre',
    'capital_initial' => 5000.0,
    'devise_principale' => 'USD',
    'devise_secondaire' => null,
    'capital_actuel' => 5000.0,
    'capital_cash' => 5000.0,
    'capital_airtel_money' => 0.0,
    'capital_mpesa' => 0.0,
    'capital_orange_money' => 0.0,
    'capital_actuel_devise2' => null,
    'capital_cash_devise2' => null,
    'capital_airtel_money_devise2' => null,
    'capital_mpesa_devise2' => null,
    'capital_orange_money_devise2' => null,
    'creances' => 0.0,
    'dettes' => 0.0,
    'last_modified_at' => date('Y-m-d H:i:s'),
    'last_modified_by' => 'test_script',
    'created_at' => date('Y-m-d H:i:s'),
    'is_synced' => false,
    'synced_at' => null
];

// Préparer le payload comme Flutter le ferait
$payload = [
    'entities' => [$testShop],
    'user_id' => 'admin',
    'timestamp' => date('c')
];

echo "📤 Données à envoyer:\n";
echo json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n\n";

// URL de l'API
$url = 'https://safdal.investee-group.com/server/api/sync/shops/upload.php';

// Initialiser cURL
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json',
]);

echo "🚀 Envoi vers: $url\n\n";

// Exécuter la requête
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);

curl_close($ch);

// Afficher le résultat
if ($error) {
    echo "❌ Erreur cURL: $error\n";
} else {
    echo "📊 Code HTTP: $httpCode\n";
    echo "📄 Réponse serveur:\n";
    
    // Essayer de formater en JSON pour une meilleure lisibilité
    $jsonResponse = json_decode($response);
    if ($jsonResponse) {
        echo json_encode($jsonResponse, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    } else {
        echo $response . "\n";
    }
}

echo "\n=== FIN DU TEST ===\n";

// Vérifier dans la base de données
echo "\n📊 Vérification dans la base de données...\n";

try {
    require_once __DIR__ . '/config/database.php';
    
    $stmt = $pdo->prepare("SELECT id, designation, is_synced, synced_at, created_at FROM shops ORDER BY created_at DESC LIMIT 5");
    $stmt->execute();
    $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "\n🏪 5 derniers shops dans la base:\n";
    foreach ($shops as $shop) {
        $syncStatus = $shop['is_synced'] ? '✅ Synchronisé' : '⏳ Non synchronisé';
        echo sprintf(
            "  - ID: %d | %s | %s | Créé: %s\n",
            $shop['id'],
            $shop['designation'],
            $syncStatus,
            $shop['created_at']
        );
    }
} catch (Exception $e) {
    echo "❌ Erreur DB: " . $e->getMessage() . "\n";
}
