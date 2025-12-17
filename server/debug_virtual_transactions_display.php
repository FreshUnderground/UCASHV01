<?php
/**
 * Script de diagnostic pour les transactions virtuelles
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🔍 Diagnostic des transactions virtuelles</h1>";

try {
    // 1. Vérifier les transactions virtuelles principales
    echo "<h2>📊 Transactions virtuelles principales</h2>";
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM virtual_transactions");
    $mainCount = $stmt->fetch()['count'];
    echo "<p><strong>Nombre total de transactions virtuelles:</strong> $mainCount</p>";
    
    if ($mainCount > 0) {
        // Afficher quelques exemples
        $stmt = $pdo->query("SELECT reference, montant_virtuel, devise, statut, date_enregistrement FROM virtual_transactions ORDER BY date_enregistrement DESC LIMIT 5");
        $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<h3>📋 Dernières transactions:</h3>";
        echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
        echo "<tr><th>Référence</th><th>Montant</th><th>Devise</th><th>Statut</th><th>Date</th></tr>";
        foreach ($samples as $tx) {
            echo "<tr>";
            echo "<td>{$tx['reference']}</td>";
            echo "<td>{$tx['montant_virtuel']}</td>";
            echo "<td>{$tx['devise']}</td>";
            echo "<td>{$tx['statut']}</td>";
            echo "<td>{$tx['date_enregistrement']}</td>";
            echo "</tr>";
        }
        echo "</table>";
    }
    
    // 2. Vérifier les tables de suppression
    echo "<h2>🗑️ Tables de suppression</h2>";
    
    // Vérifier si les tables existent
    $tables = ['virtual_transaction_deletion_requests', 'virtual_transactions_corbeille'];
    foreach ($tables as $table) {
        $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
        $exists = $stmt->fetch();
        
        if ($exists) {
            $stmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
            $count = $stmt->fetch()['count'];
            echo "<p><strong>Table $table:</strong> ✅ Existe ($count enregistrements)</p>";
        } else {
            echo "<p><strong>Table $table:</strong> ❌ N'existe pas</p>";
        }
    }
    
    // 3. Tester l'API de download des demandes de suppression
    echo "<h2>🔗 Test API download des demandes de suppression</h2>";
    
    $apiUrl = "http://localhost/UCASHV01/server/api/sync/virtual_transaction_deletion_requests/download.php";
    
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => 'Content-Type: application/json',
            'timeout' => 10
        ]
    ]);
    
    $response = @file_get_contents($apiUrl, false, $context);
    
    if ($response !== false) {
        $data = json_decode($response, true);
        echo "<p><strong>API Response:</strong> ✅ Succès</p>";
        echo "<pre>" . htmlspecialchars(json_encode($data, JSON_PRETTY_PRINT)) . "</pre>";
    } else {
        echo "<p><strong>API Response:</strong> ❌ Erreur de connexion</p>";
        echo "<p>URL testée: $apiUrl</p>";
    }
    
    // 4. Vérifier l'API des transactions virtuelles principales
    echo "<h2>🔗 Test API transactions virtuelles principales</h2>";
    
    $mainApiUrl = "http://localhost/UCASHV01/server/api/sync/virtual_transactions/changes.php";
    
    $response = @file_get_contents($mainApiUrl, false, $context);
    
    if ($response !== false) {
        $data = json_decode($response, true);
        echo "<p><strong>API Response:</strong> ✅ Succès</p>";
        if (isset($data['data']) && is_array($data['data'])) {
            echo "<p><strong>Nombre de transactions retournées:</strong> " . count($data['data']) . "</p>";
        }
        echo "<pre>" . htmlspecialchars(substr(json_encode($data, JSON_PRETTY_PRINT), 0, 1000)) . "...</pre>";
    } else {
        echo "<p><strong>API Response:</strong> ❌ Erreur de connexion</p>";
        echo "<p>URL testée: $mainApiUrl</p>";
    }
    
    // 5. Diagnostic du problème
    echo "<h2>🎯 Diagnostic</h2>";
    
    if ($mainCount == 0) {
        echo "<div style='background: #ffebee; padding: 10px; border-left: 4px solid #f44336;'>";
        echo "<h3>❌ Problème identifié: Aucune transaction virtuelle</h3>";
        echo "<p>Il n'y a aucune transaction virtuelle dans la base de données.</p>";
        echo "<p><strong>Solution:</strong> Créez d'abord des transactions virtuelles via l'application Flutter.</p>";
        echo "</div>";
    } else {
        echo "<div style='background: #e8f5e8; padding: 10px; border-left: 4px solid #4caf50;'>";
        echo "<h3>✅ Transactions virtuelles trouvées</h3>";
        echo "<p>Il y a $mainCount transactions virtuelles dans la base de données.</p>";
        echo "<p><strong>Note:</strong> Les APIs de suppression sont vides car aucune demande de suppression n'a été créée.</p>";
        echo "<p><strong>Pour tester le système de suppression:</strong></p>";
        echo "<ol>";
        echo "<li>Utilisez l'interface Flutter pour créer une demande de suppression</li>";
        echo "<li>Ou créez une demande manuellement via l'API upload</li>";
        echo "</ol>";
        echo "</div>";
    }
    
} catch (Exception $e) {
    echo "<div style='background: #ffebee; padding: 10px; border-left: 4px solid #f44336;'>";
    echo "<h3>❌ Erreur</h3>";
    echo "<p><strong>Message:</strong> " . $e->getMessage() . "</p>";
    echo "<p><strong>Fichier:</strong> " . $e->getFile() . "</p>";
    echo "<p><strong>Ligne:</strong> " . $e->getLine() . "</p>";
    echo "</div>";
}
?>

<style>
body { font-family: Arial, sans-serif; margin: 20px; }
table { margin: 10px 0; }
th, td { padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
</style>
