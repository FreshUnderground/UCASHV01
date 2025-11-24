<?php
/**
 * Script de test pour le système de commissions shop-to-shop
 * Permet de tester la création et la récupération de commissions spécifiques aux routes
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../../../config/database.php';

try {
    // Test 1: Créer une commission spécifique route (BUTEMBO -> KAMPALA)
    echo "Test 1: Création d'une commission spécifique route...\n";
    
    $stmt = $pdo->prepare("
        INSERT INTO commissions (
            source_shop_id, destination_shop_id, type, taux, description, is_active
        ) VALUES (?, ?, ?, ?, ?, ?)
    ");
    
    $result = $stmt->execute([1, 2, 'SORTANT', 1.0, 'Commission BUTEMBO-KAMPALA', 1]);
    echo $result ? "✓ Commission route créée\n" : "✗ Échec création commission route\n";
    
    // Test 2: Créer une commission par source uniquement (BUTEMBO -> toutes destinations)
    echo "Test 2: Création d'une commission source uniquement...\n";
    
    $stmt = $pdo->prepare("
        INSERT INTO commissions (
            source_shop_id, destination_shop_id, type, taux, description, is_active
        ) VALUES (?, ?, ?, ?, ?, ?)
    ");
    
    $result = $stmt->execute([1, null, 'SORTANT', 1.5, 'Commission BUTEMBO par défaut', 1]);
    echo $result ? "✓ Commission source créée\n" : "✗ Échec création commission source\n";
    
    // Test 3: Créer une commission globale
    echo "Test 3: Création d'une commission globale...\n";
    
    $stmt = $pdo->prepare("
        INSERT INTO commissions (
            source_shop_id, destination_shop_id, type, taux, description, is_active
        ) VALUES (?, ?, ?, ?, ?, ?)
    ");
    
    $result = $stmt->execute([null, null, 'SORTANT', 2.0, 'Commission globale par défaut', 1]);
    echo $result ? "✓ Commission globale créée\n" : "✗ Échec création commission globale\n";
    
    // Test 4: Récupérer les commissions pour un transfert (BUTEMBO -> KAMPALA)
    echo "Test 4: Récupération des commissions pour un transfert spécifique...\n";
    
    // Requête pour trouver la commission la plus appropriée
    $stmt = $pdo->prepare("
        SELECT * FROM commissions 
        WHERE (source_shop_id = ? AND destination_shop_id = ? AND type = ?)
           OR (source_shop_id = ? AND destination_shop_id IS NULL AND type = ?)
           OR (source_shop_id IS NULL AND destination_shop_id IS NULL AND type = ?)
        ORDER BY 
            CASE 
                WHEN source_shop_id = ? AND destination_shop_id = ? THEN 1
                WHEN source_shop_id = ? AND destination_shop_id IS NULL THEN 2
                WHEN source_shop_id IS NULL AND destination_shop_id IS NULL THEN 3
            END
        LIMIT 1
    ");
    
    $stmt->execute([1, 2, 'SORTANT', 1, 'SORTANT', 'SORTANT', 1, 2, 1]);
    $commission = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($commission) {
        echo "✓ Commission trouvée: {$commission['description']} ({$commission['taux']}%)\n";
        echo "  Hiérarchie: " . 
             ($commission['source_shop_id'] && $commission['destination_shop_id'] ? "Route spécifique" :
              ($commission['source_shop_id'] && !$commission['destination_shop_id'] ? "Source uniquement" : "Globale")) . "\n";
    } else {
        echo "✗ Aucune commission trouvée\n";
    }
    
    // Test 5: Récupérer toutes les commissions pour un shop source
    echo "Test 5: Récupération de toutes les commissions pour un shop source...\n";
    
    $stmt = $pdo->prepare("
        SELECT * FROM commissions 
        WHERE source_shop_id = ? OR source_shop_id IS NULL
        ORDER BY source_shop_id DESC, destination_shop_id DESC
    ");
    
    $stmt->execute([1]);
    $commissions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "✓ " . count($commissions) . " commissions trouvées pour le shop source 1\n";
    
    foreach ($commissions as $c) {
        $source = $c['source_shop_id'] ?: 'Global';
        $dest = $c['destination_shop_id'] ?: 'Toutes';
        echo "  - {$c['description']}: {$source} -> {$dest} ({$c['taux']}%)\n";
    }
    
    echo "\n=== Tests terminés ===\n";
    
} catch (Exception $e) {
    echo "Erreur: " . $e->getMessage() . "\n";
}
?>