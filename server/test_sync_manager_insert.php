<?php
// Test SyncManager shop insertion
require_once 'config/database.php';
require_once 'classes/SyncManager.php';

try {
    $syncManager = new SyncManager($pdo);
    
    // Test data similar to what the Flutter app would send
    $testData = [
        'id' => 1,
        'designation' => 'Test Shop',
        'localisation' => 'Test Location',
        'capital_initial' => 10000,
        'devise_principale' => 'USD',
        'devise_secondaire' => null,
        'capital_actuel' => 10000,
        'capital_cash' => 5000,
        'capital_airtel_money' => 2000,
        'capital_mpesa' => 2000,
        'capital_orange_money' => 1000,
        'capital_actuel_devise2' => null,
        'capital_cash_devise2' => null,
        'capital_airtel_money_devise2' => null,
        'capital_mpesa_devise2' => null,
        'capital_orange_money_devise2' => null,
        'creances' => 0,
        'dettes' => 0,
        'last_modified_at' => date('c'),
        'last_modified_by' => 'test',
        'created_at' => date('c'),
        'is_synced' => false,
        'synced_at' => null
    ];
    
    echo "Testing SyncManager insertShop...\n";
    $result = $syncManager->saveShop($testData);
    echo "✅ SaveShop result: " . print_r($result, true) . "\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
?>