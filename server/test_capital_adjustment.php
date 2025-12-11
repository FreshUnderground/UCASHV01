<?php
/**
 * Script de test pour l'API d'ajustement de capital
 * 
 * Ce script teste:
 * 1. Création d'un ajustement d'augmentation de capital
 * 2. Création d'un ajustement de diminution de capital
 * 3. Récupération de l'historique des ajustements
 * 4. Vérification dans la base de données
 */

require_once 'config/database.php';

echo str_repeat('=', 80) . "\n";
echo "TEST - API d'Ajustement de Capital avec Traçabilité\n";
echo str_repeat('=', 80) . "\n\n";

// Étape 1: Trouver un shop existant
echo "📊 Étape 1: Recherche d'un shop existant...\n";
$stmt = $pdo->query("SELECT * FROM shops ORDER BY id ASC LIMIT 1");
$shop = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$shop) {
    die("❌ Aucun shop trouvé dans la base de données. Créez un shop d'abord.\n");
}

echo "✅ Shop trouvé:\n";
echo "   - ID: {$shop['id']}\n";
echo "   - Designation: {$shop['designation']}\n";
echo "   - Capital actuel: {$shop['capital_actuel']} {$shop['devise_principale']}\n";
echo "   - Capital cash: {$shop['capital_cash']} {$shop['devise_principale']}\n\n";

$shopId = $shop['id'];
$capitalBefore = $shop['capital_actuel'];
$capitalCashBefore = $shop['capital_cash'];

// Étape 2: Test d'AUGMENTATION de capital
echo "📤 Étape 2: Test d'augmentation de capital (+3000 USD en Cash)...\n";

$increaseData = [
    'shop_id' => $shopId,
    'adjustment_type' => 'INCREASE',
    'amount' => 3000.00,
    'mode_paiement' => 'cash',
    'reason' => 'Test injection capital - Augmentation fonds de roulement',
    'description' => 'Test automatisé de l\'API d\'ajustement de capital',
    'admin_id' => 1,
    'admin_username' => 'admin_test'
];

$ch = curl_init('http://localhost/UCASHV01/server/api/audit/log_capital_adjustment.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($increaseData));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "📊 Code HTTP: $httpCode\n";

if ($httpCode == 200) {
    $result = json_decode($response, true);
    if ($result['success']) {
        echo "✅ Augmentation enregistrée avec succès!\n";
        echo "   - Audit ID: {$result['adjustment']['audit_id']}\n";
        echo "   - Capital avant: {$result['adjustment']['capital_before']} USD\n";
        echo "   - Capital après: {$result['adjustment']['capital_after']} USD\n";
        echo "   - Différence: +{$result['adjustment']['amount']} USD\n";
        echo "   - Cash avant: {$result['details']['cash']['before']} USD\n";
        echo "   - Cash après: {$result['details']['cash']['after']} USD\n\n";
    } else {
        echo "❌ Erreur: {$result['message']}\n";
        die();
    }
} else {
    echo "❌ Erreur HTTP: $httpCode\n";
    echo "Réponse: $response\n";
    die();
}

// Attendre un peu
sleep(1);

// Étape 3: Test de DIMINUTION de capital
echo "📤 Étape 3: Test de diminution de capital (-1000 USD en M-Pesa)...\n";

$decreaseData = [
    'shop_id' => $shopId,
    'adjustment_type' => 'DECREASE',
    'amount' => 1000.00,
    'mode_paiement' => 'mpesa',
    'reason' => 'Test retrait capital - Retrait partiel investissement',
    'description' => 'Test automatisé de la diminution de capital',
    'admin_id' => 1,
    'admin_username' => 'admin_test'
];

$ch = curl_init('http://localhost/UCASHV01/server/api/audit/log_capital_adjustment.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($decreaseData));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "📊 Code HTTP: $httpCode\n";

if ($httpCode == 200) {
    $result = json_decode($response, true);
    if ($result['success']) {
        echo "✅ Diminution enregistrée avec succès!\n";
        echo "   - Audit ID: {$result['adjustment']['audit_id']}\n";
        echo "   - Capital avant: {$result['adjustment']['capital_before']} USD\n";
        echo "   - Capital après: {$result['adjustment']['capital_after']} USD\n";
        echo "   - Différence: -{$result['adjustment']['amount']} USD\n";
        echo "   - M-Pesa avant: {$result['details']['mpesa']['before']} USD\n";
        echo "   - M-Pesa après: {$result['details']['mpesa']['after']} USD\n\n";
    } else {
        echo "❌ Erreur: {$result['message']}\n";
        die();
    }
} else {
    echo "❌ Erreur HTTP: $httpCode\n";
    echo "Réponse: $response\n";
    die();
}

// Étape 4: Récupérer l'historique
echo "📊 Étape 4: Récupération de l'historique des ajustements...\n";

$ch = curl_init("http://localhost/UCASHV01/server/api/audit/get_capital_adjustments.php?shop_id=$shopId&limit=10");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "📊 Code HTTP: $httpCode\n";

if ($httpCode == 200) {
    $result = json_decode($response, true);
    if ($result['success']) {
        echo "✅ Historique récupéré avec succès!\n";
        echo "   - Total ajustements: {$result['summary']['total_adjustments']}\n";
        echo "   - Augmentations: {$result['summary']['count_increases']} (+{$result['summary']['total_increases']} USD)\n";
        echo "   - Diminutions: {$result['summary']['count_decreases']} (-{$result['summary']['total_decreases']} USD)\n";
        echo "   - Changement net: {$result['summary']['net_change']} USD\n\n";
        
        echo "📋 Derniers ajustements:\n";
        foreach (array_slice($result['adjustments'], 0, 5) as $adj) {
            $sign = $adj['adjustment_type'] === 'CAPITAL_INCREASE' ? '+' : '-';
            echo "   - [{$adj['created_at']}] {$adj['adjustment_type']}: {$sign}{$adj['amount']} USD\n";
            echo "     Raison: {$adj['reason']}\n";
            echo "     Admin: {$adj['admin_username']} | Audit ID: {$adj['id']}\n";
            echo "     Capital: {$adj['capital_before']} → {$adj['capital_after']} USD\n\n";
        }
    } else {
        echo "❌ Erreur: {$result['message']}\n";
    }
} else {
    echo "❌ Erreur HTTP: $httpCode\n";
}

// Étape 5: Vérification dans la base de données
echo "\n📊 Étape 5: Vérification dans la base de données...\n";

// Vérifier le shop
$stmt = $pdo->prepare("SELECT * FROM shops WHERE id = ?");
$stmt->execute([$shopId]);
$shopAfter = $stmt->fetch(PDO::FETCH_ASSOC);

echo "🏪 Shop après ajustements:\n";
echo "   - Capital actuel: {$shopAfter['capital_actuel']} USD\n";
echo "   - Capital cash: {$shopAfter['capital_cash']} USD\n";
echo "   - Capital M-Pesa: {$shopAfter['capital_mpesa']} USD\n\n";

// Vérifier l'audit log
$stmt = $pdo->prepare("
    SELECT COUNT(*) as count 
    FROM audit_log 
    WHERE table_name = 'shops' 
      AND record_id = ? 
      AND action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE')
");
$stmt->execute([$shopId]);
$auditCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

echo "📝 Entrées d'audit pour ce shop: $auditCount\n";

// Calculer les changements attendus
$expectedCapital = $capitalBefore + 3000 - 1000;
$expectedCash = $capitalCashBefore + 3000;
$expectedMPesa = $shop['capital_mpesa'] - 1000;

echo "\n🔍 Vérification des calculs:\n";
echo "   Capital avant tests: $capitalBefore USD\n";
echo "   + Augmentation: +3000 USD (cash)\n";
echo "   - Diminution: -1000 USD (mpesa)\n";
echo "   = Capital attendu: $expectedCapital USD\n";
echo "   = Capital réel: {$shopAfter['capital_actuel']} USD\n";

if (abs($shopAfter['capital_actuel'] - $expectedCapital) < 0.01) {
    echo "   ✅ Capital correct!\n";
} else {
    echo "   ❌ Écart détecté!\n";
}

if (abs($shopAfter['capital_cash'] - $expectedCash) < 0.01) {
    echo "   ✅ Cash correct!\n";
} else {
    echo "   ❌ Cash incorrect!\n";
}

echo "\n" . str_repeat('=', 80) . "\n";
echo "✅ TESTS TERMINÉS AVEC SUCCÈS!\n";
echo str_repeat('=', 80) . "\n\n";

echo "💡 Requête SQL pour voir l'historique complet:\n";
echo "SELECT * FROM audit_log WHERE table_name = 'shops' AND action IN ('CAPITAL_INCREASE', 'CAPITAL_DECREASE') ORDER BY created_at DESC;\n\n";
