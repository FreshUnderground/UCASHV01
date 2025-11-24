<?php
/**
 * Vérifie la structure de la table commissions
 */

header('Content-Type: text/plain; charset=utf-8');

require_once __DIR__ . '/../../../config/database.php';

echo "=== VÉRIFICATION TABLE COMMISSIONS ===\n\n";

try {
    // 1. Vérifier si la table existe
    $stmt = $pdo->query("SHOW TABLES LIKE 'commissions'");
    $tableExists = $stmt->rowCount() > 0;
    
    if (!$tableExists) {
        echo "❌ La table 'commissions' n'existe PAS!\n";
        echo "   Vous devez exécuter le script de migration: update_commissions_for_new_app.sql\n";
        exit;
    }
    
    echo "✅ La table 'commissions' existe\n\n";
    
    // 2. Afficher la structure
    echo "=== STRUCTURE DE LA TABLE ===\n\n";
    $stmt = $pdo->query("DESCRIBE commissions");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Colonnes présentes:\n";
    foreach ($columns as $col) {
        echo "  - {$col['Field']} ({$col['Type']}) {$col['Null']} {$col['Key']}\n";
    }
    
    // 3. Vérifier les colonnes critiques
    echo "\n=== VÉRIFICATION COLONNES CRITIQUES ===\n\n";
    $requiredColumns = ['id', 'type', 'taux', 'description', 'shop_id', 'shop_source_id', 'shop_destination_id', 'is_synced', 'synced_at'];
    $existingColumns = array_column($columns, 'Field');
    
    foreach ($requiredColumns as $col) {
        if (in_array($col, $existingColumns)) {
            echo "✅ $col\n";
        } else {
            echo "❌ $col (MANQUANTE!)\n";
        }
    }
    
    // 4. Compter les commissions existantes
    echo "\n=== DONNÉES EXISTANTES ===\n\n";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM commissions");
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    echo "Nombre de commissions: $count\n\n";
    
    if ($count > 0) {
        echo "Dernières commissions:\n";
        $stmt = $pdo->query("SELECT * FROM commissions ORDER BY id DESC LIMIT 5");
        $commissions = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($commissions as $comm) {
            echo "  ID: {$comm['id']}\n";
            echo "  Type: " . ($comm['type'] ?? 'N/A') . "\n";
            echo "  Taux: " . ($comm['taux'] ?? 'N/A') . "%\n";
            echo "  Description: " . ($comm['description'] ?? 'N/A') . "\n";
            echo "  ShopId: " . ($comm['shop_id'] ?? 'NULL') . "\n";
            echo "  SourceId: " . ($comm['shop_source_id'] ?? 'NULL') . "\n";
            echo "  DestId: " . ($comm['shop_destination_id'] ?? 'NULL') . "\n";
            echo "  Synced: " . ($comm['is_synced'] ?? 'N/A') . "\n";
            echo "  ---\n";
        }
    }
    
} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    echo "\nStack trace:\n" . $e->getTraceAsString() . "\n";
}
