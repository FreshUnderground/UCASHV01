<?php
// Test shop insertion
require_once 'config/database.php';

try {
    // Test a simple insert
    $sql = "INSERT INTO shops (
        designation, localisation, 
        capital_initial, 
        devise_principale, devise_secondaire,
        capital_actuel, capital_cash, capital_airtel_money, capital_mpesa, capital_orange_money,
        capital_actuel_devise2, capital_cash_devise2, capital_airtel_money_devise2, capital_mpesa_devise2, capital_orange_money_devise2,
        creances, dettes, 
        last_modified_at, last_modified_by, created_at,
        is_synced, synced_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    
    echo "SQL: $sql\n";
    
    $stmt = $pdo->prepare($sql);
    $result = $stmt->execute([
        'Test Shop',
        'Test Location',
        10000,
        'USD',
        null,
        10000,
        5000,
        2000,
        2000,
        1000,
        null,
        null,
        null,
        null,
        null,
        0,
        0,
        date('c'),
        'system',
        date('c'),
        1,
        date('c')
    ]);
    
    if ($result) {
        echo "✅ Insert successful! Last insert ID: " . $pdo->lastInsertId() . "\n";
    } else {
        echo "❌ Insert failed!\n";
    }
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Line: " . $e->getLine() . "\n";
}
?>