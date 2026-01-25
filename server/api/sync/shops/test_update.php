<?php
/**
 * Script de test pour l'endpoint de mise à jour de shop
 * Usage: Exécuter via navigateur ou CLI
 */

header('Content-Type: text/plain; charset=utf-8');

echo "=== TEST MISE À JOUR SHOP ===\n\n";

// 1. Vérifier qu'il y a au moins un shop dans la base
require_once __DIR__ . '/../../../config/database.php';

echo "📊 Étape 1: Recherche d'un shop existant...\n";
$stmt = $pdo->query("SELECT id, designation, localisation, capital_actuel FROM shops LIMIT 1");
$shop = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$shop) {
    echo "❌ Aucun shop trouvé dans la base de données!\n";
    echo "   Créez d'abord un shop avant de tester la mise à jour.\n";
    exit(1);
}

echo "✅ Shop trouvé:\n";
echo "   - ID: {$shop['id']}\n";
echo "   - Designation: {$shop['designation']}\n";
echo "   - Localisation: {$shop['localisation']}\n";
echo "   - Capital actuel: {$shop['capital_actuel']} USD\n\n";

// 2. Préparer les données de mise à jour
$shopId = $shop['id'];
$newDesignation = $shop['designation'] . " (MODIFIÉ)";
$newLocalisation = "Butembo - Test Zone";
$newCapital = 15000.0;

$updateData = [
    'shop_id' => $shopId,
    'designation' => $newDesignation,
    'localisation' => $newLocalisation,
    'capital_initial' => $newCapital,
    'devise_principale' => 'USD',
    'devise_secondaire' => 'CDF',
    'capital_actuel' => $newCapital,
    'capital_cash' => $newCapital,
    'capital_airtel_money' => 0.0,
    'capital_mpesa' => 0.0,
    'capital_orange_money' => 0.0,
    'capital_actuel_devise2' => 0.0,
    'capital_cash_devise2' => 0.0,
    'capital_airtel_money_devise2' => 0.0,
    'capital_mpesa_devise2' => 0.0,
    'capital_orange_money_devise2' => 0.0,
    'creances' => 0.0,
    'dettes' => 0.0,
    'user_id' => 'admin_test',
    'timestamp' => date('c')
];

echo "📤 Étape 2: Envoi de la requête de mise à jour...\n";
echo "   Nouveau nom: $newDesignation\n";
echo "   Nouvelle localisation: $newLocalisation\n";
echo "   Nouveau capital: $newCapital USD\n\n";

// 3. Envoyer la requête à l'API
$url = 'https://safdal.investee-group.com/server/api/sync/shops/update.php';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($updateData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Accept: application/json',
]);

echo "🚀 Étape 3: Exécution de la requête...\n";
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($curlError) {
    echo "❌ Erreur cURL: $curlError\n";
    exit(1);
}

echo "📊 Code HTTP: $httpCode\n\n";

// 4. Analyser la réponse
echo "📄 Étape 4: Réponse du serveur:\n";
echo "----------------------------------------\n";

$jsonResponse = json_decode($response, true);
if ($jsonResponse) {
    echo json_encode($jsonResponse, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
    echo "----------------------------------------\n\n";
    
    if ($jsonResponse['success']) {
        echo "✅ Mise à jour réussie!\n\n";
        
        // Afficher les agents affectés
        if (isset($jsonResponse['affected_agents'])) {
            $count = $jsonResponse['affected_agents']['count'];
            echo "👥 Agents affectés: $count\n";
            
            if ($count > 0) {
                foreach ($jsonResponse['affected_agents']['agents'] as $agent) {
                    echo "   - {$agent['nom']} ({$agent['username']})\n";
                }
            } else {
                echo "   ℹ️ Aucun agent associé à ce shop\n";
            }
        }
        echo "\n";
    } else {
        echo "❌ Erreur: {$jsonResponse['message']}\n\n";
    }
} else {
    echo "Réponse brute:\n$response\n";
    echo "----------------------------------------\n\n";
    echo "❌ Impossible de décoder la réponse JSON\n\n";
}

// 5. Vérifier dans la base de données
echo "🔍 Étape 5: Vérification dans la base de données...\n";
$checkStmt = $pdo->prepare("SELECT id, designation, localisation, capital_actuel, last_modified_at FROM shops WHERE id = ?");
$checkStmt->execute([$shopId]);
$updatedShop = $checkStmt->fetch(PDO::FETCH_ASSOC);

if ($updatedShop) {
    echo "📊 Shop après mise à jour:\n";
    echo "   - ID: {$updatedShop['id']}\n";
    echo "   - Designation: {$updatedShop['designation']}\n";
    echo "   - Localisation: {$updatedShop['localisation']}\n";
    echo "   - Capital: {$updatedShop['capital_actuel']} USD\n";
    echo "   - Dernière modification: {$updatedShop['last_modified_at']}\n\n";
    
    // Comparer les valeurs
    if ($updatedShop['designation'] === $newDesignation) {
        echo "✅ Designation mise à jour correctement\n";
    } else {
        echo "❌ Designation non mise à jour (attendu: $newDesignation, reçu: {$updatedShop['designation']})\n";
    }
    
    if ($updatedShop['localisation'] === $newLocalisation) {
        echo "✅ Localisation mise à jour correctement\n";
    } else {
        echo "❌ Localisation non mise à jour\n";
    }
    
    if ((float)$updatedShop['capital_actuel'] === $newCapital) {
        echo "✅ Capital mis à jour correctement\n";
    } else {
        echo "❌ Capital non mis à jour\n";
    }
} else {
    echo "❌ Shop introuvable après mise à jour!\n";
}

echo "\n=== FIN DU TEST ===\n";
