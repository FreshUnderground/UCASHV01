<?php
// Test script to verify billetage insertion
// Using local database connection

try {
    // Local database connection
    $pdo = new PDO("mysql:host=localhost;dbname=ucash_db;charset=utf8", "root", "");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Sample billetage data
    $billetage_data = json_encode([
        "denominations" => [
            "100" => 5,
            "50" => 2,
            "20" => 0,
            "10" => 0,
            "5" => 0,
            "1" => 0,
            "0.25" => 0,
            "0.10" => 0,
            "0.05" => 0,
            "0.01" => 0
        ]
    ]);
    
    // Insert a test operation with billetage
    $stmt = $pdo->prepare("
        INSERT INTO operations (
            type, montant_brut, montant_net, commission, devise,
            client_id, client_nom, shop_source_id, agent_id,
            mode_paiement, statut, reference, notes, billetage,
            last_modified_at, last_modified_by, created_at
        ) VALUES (
            :type, :montant_brut, :montant_net, :commission, :devise,
            :client_id, :client_nom, :shop_source_id, :agent_id,
            :mode_paiement, :statut, :reference, :notes, :billetage,
            :last_modified_at, :last_modified_by, :created_at
        )
    ");
    
    $result = $stmt->execute([
        ':type' => 'retrait',
        ':montant_brut' => 1000.00,
        ':montant_net' => 1000.00,
        ':commission' => 0.00,
        ':devise' => 'USD',
        ':client_id' => null,
        ':client_nom' => 'Test Client',
        ':shop_source_id' => 1,
        ':agent_id' => 1,
        ':mode_paiement' => 'cash',
        ':statut' => 'terminee',
        ':reference' => 'TEST_' . time(),
        ':notes' => 'Test operation with billetage',
        ':billetage' => $billetage_data,
        ':last_modified_at' => date('Y-m-d H:i:s'),
        ':last_modified_by' => 'test_script',
        ':created_at' => date('Y-m-d H:i:s')
    ]);
    
    if ($result) {
        $insertId = $pdo->lastInsertId();
        echo "✓ Successfully inserted test operation with ID: $insertId\n";
        
        // Verify the billetage data was stored
        $verifyStmt = $pdo->prepare("SELECT billetage FROM operations WHERE id = ?");
        $verifyStmt->execute([$insertId]);
        $row = $verifyStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($row && $row['billetage']) {
            echo "✓ Billetage data successfully stored: " . $row['billetage'] . "\n";
        } else {
            echo "✗ Billetage data not found or empty\n";
        }
    } else {
        echo "✗ Failed to insert test operation\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>