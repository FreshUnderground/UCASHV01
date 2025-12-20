<?php
/**
 * Test direct de l'upload de SIMs pour identifier l'erreur 500
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

echo "<pre>";
echo "========================================\n";
echo "TEST DIRECT UPLOAD SIMS\n";
echo "========================================\n\n";

require_once __DIR__ . '/config/database.php';

try {
    // $pdo est défini dans database.php
    $conn = $pdo;
    
    echo "✅ Connexion à la base de données réussie\n\n";
    
    // 1. Vérifier les shops disponibles
    echo "1. SHOPS DISPONIBLES:\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("SELECT id, designation FROM shops ORDER BY id LIMIT 10");
    $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($shops)) {
        echo "⚠️ AUCUN SHOP TROUVÉ!\n\n";
    } else {
        foreach ($shops as $shop) {
            echo "  - Shop #{$shop['id']}: {$shop['designation']}\n";
        }
        echo "\n";
    }
    
    // 2. Lire un exemple de données envoyées par Flutter
    echo "2. SIMULATION D'UPLOAD:\n";
    echo "----------------------------------------\n";
    
    // Simuler les données envoyées par Flutter (utiliser le premier shop disponible)
    $testShopId = !empty($shops) ? $shops[0]['id'] : 1;
    
    $testData = [
        'entities' => [
            [
                'id' => 1764391195616, // ID différent de celui qui échoue
                'numero' => '0850999999',
                'operateur' => 'Airtel',
                'shop_id' => $testShopId,
                'shop_designation' => $shops[0]['designation'] ?? 'Test Shop',
                'solde_initial' => 0.0,
                'solde_actuel' => 0.0,
                'statut' => 'active',
                'date_creation' => date('Y-m-d H:i:s'),
                'last_modified_at' => date('Y-m-d H:i:s'),
            ]
        ],
        'user_id' => 'test_user',
        'user_role' => 'admin',
        'timestamp' => date('c')
    ];
    
    echo "Données de test à uploader:\n";
    echo json_encode($testData, JSON_PRETTY_PRINT) . "\n\n";
    
    // 3. Tester l'upload via cURL
    echo "3. TEST UPLOAD VIA CURL:\n";
    echo "----------------------------------------\n";
    
    // Tester d'abord la version simple
    $uploadUrl = 'https://mahanaimeservice.investee-group.com/server/api/sync/sims/upload_simple_test.php';
    echo "URL de test: $uploadUrl\n\n";
    
    $ch = curl_init($uploadUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($testData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json; charset=utf-8',
        'Accept: application/json',
    ]);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // Pour test seulement
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    
    echo "Code HTTP: $httpCode\n";
    
    if ($curlError) {
        echo "Erreur cURL: $curlError\n";
    }
    
    echo "Réponse:\n";
    
    if ($httpCode == 200) {
        echo "✅ SUCCESS!\n";
        $result = json_decode($response, true);
        echo json_encode($result, JSON_PRETTY_PRINT) . "\n\n";
    } else {
        echo "❌ ERREUR $httpCode\n";
        echo "Réponse brute:\n";
        echo $response . "\n\n";
    }
    
    // 4. Vérifier les SIMs en base après le test
    echo "4. VÉRIFICATION DES SIMS EN BASE:\n";
    echo "----------------------------------------\n";
    $stmt = $conn->query("SELECT id, numero, operateur, shop_id, statut FROM sims ORDER BY id DESC LIMIT 5");
    $recentSims = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Dernières SIMs en base:\n";
    foreach ($recentSims as $sim) {
        echo "  - SIM #{$sim['id']}: {$sim['numero']} ({$sim['operateur']}) - Shop: {$sim['shop_id']} - Statut: {$sim['statut']}\n";
    }
    echo "\n";
    
    // 5. Tester avec les données qui échouent actuellement
    echo "5. TEST AVEC SIM QUI ÉCHOUE (ID 1764391195615):\n";
    echo "----------------------------------------\n";
    
    // Vérifier si cette SIM existe déjà
    $stmt = $conn->prepare("SELECT * FROM sims WHERE id = ?");
    $stmt->execute([1764391195615]);
    $existingSim = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($existingSim) {
        echo "⚠️ Cette SIM existe déjà en base:\n";
        echo json_encode($existingSim, JSON_PRETTY_PRINT) . "\n\n";
    } else {
        echo "ℹ️ Cette SIM n'existe pas encore en base\n\n";
    }
    
    echo "========================================\n";
    echo "TEST TERMINÉ\n";
    echo "========================================\n";
    
} catch (Exception $e) {
    echo "\n❌ ERREUR: " . $e->getMessage() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}

echo "</pre>";
