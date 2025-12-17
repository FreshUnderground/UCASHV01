<?php
/**
 * Script de diagnostic pour vérifier les demandes de suppression de transactions virtuelles
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🔍 Diagnostic des demandes de suppression VT</h1>";

try {
    // 1. Vérifier si les tables existent
    echo "<h2>📊 Vérification des tables</h2>";
    
    $tables = [
        'virtual_transaction_deletion_requests' => 'Demandes de suppression VT',
        'virtual_transactions_corbeille' => 'Corbeille VT'
    ];
    
    foreach ($tables as $table => $description) {
        $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
        $exists = $stmt->fetch();
        
        if ($exists) {
            $stmt = $pdo->query("SELECT COUNT(*) as count FROM $table");
            $count = $stmt->fetch()['count'];
            echo "<p>✅ <strong>$description:</strong> $count enregistrements</p>";
            
            if ($count > 0) {
                // Afficher quelques exemples
                $stmt = $pdo->query("SELECT * FROM $table ORDER BY created_at DESC LIMIT 3");
                $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                echo "<h3>📋 Derniers enregistrements dans $table:</h3>";
                echo "<table border='1' style='border-collapse: collapse; width: 100%; margin: 10px 0;'>";
                
                if (!empty($samples)) {
                    // En-têtes
                    echo "<tr>";
                    foreach (array_keys($samples[0]) as $key) {
                        echo "<th style='padding: 5px; background: #f0f0f0;'>$key</th>";
                    }
                    echo "</tr>";
                    
                    // Données
                    foreach ($samples as $row) {
                        echo "<tr>";
                        foreach ($row as $value) {
                            $displayValue = $value ? (strlen($value) > 50 ? substr($value, 0, 50) . '...' : $value) : 'NULL';
                            echo "<td style='padding: 5px;'>$displayValue</td>";
                        }
                        echo "</tr>";
                    }
                }
                echo "</table>";
            }
        } else {
            echo "<p>❌ <strong>$description:</strong> Table n'existe pas</p>";
        }
    }
    
    // 2. Tester l'API de download
    echo "<h2>🔗 Test de l'API de download</h2>";
    
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
        echo "<p><strong>✅ API Response:</strong> Succès</p>";
        echo "<p><strong>Nombre de demandes retournées:</strong> " . (isset($data['count']) ? $data['count'] : 'N/A') . "</p>";
        echo "<h3>📄 Réponse complète:</h3>";
        echo "<pre style='background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto;'>" . htmlspecialchars(json_encode($data, JSON_PRETTY_PRINT)) . "</pre>";
    } else {
        echo "<p><strong>❌ API Response:</strong> Erreur de connexion</p>";
        echo "<p>URL testée: $apiUrl</p>";
        
        // Vérifier si le fichier existe
        $filePath = __DIR__ . '/api/sync/virtual_transaction_deletion_requests/download.php';
        if (file_exists($filePath)) {
            echo "<p>✅ Le fichier API existe: $filePath</p>";
        } else {
            echo "<p>❌ Le fichier API n'existe pas: $filePath</p>";
        }
    }
    
    // 3. Vérifier les demandes par statut
    echo "<h2>📈 Répartition par statut</h2>";
    
    $stmt = $pdo->query("
        SELECT statut, COUNT(*) as count 
        FROM virtual_transaction_deletion_requests 
        GROUP BY statut 
        ORDER BY count DESC
    ");
    $statusCounts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($statusCounts)) {
        echo "<p>Aucune demande de suppression trouvée.</p>";
        echo "<div style='background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 10px 0;'>";
        echo "<h3>💡 Solution</h3>";
        echo "<p>Pour créer des demandes de test, utilisez :</p>";
        echo "<p><a href='/UCASHV01/server/create_sample_deletion_requests.php' style='background: #007bff; color: white; padding: 8px 15px; text-decoration: none; border-radius: 5px;'>Créer des demandes de test</a></p>";
        echo "</div>";
    } else {
        echo "<table border='1' style='border-collapse: collapse; margin: 10px 0;'>";
        echo "<tr><th style='padding: 8px; background: #f0f0f0;'>Statut</th><th style='padding: 8px; background: #f0f0f0;'>Nombre</th></tr>";
        foreach ($statusCounts as $status) {
            echo "<tr>";
            echo "<td style='padding: 8px;'>{$status['statut']}</td>";
            echo "<td style='padding: 8px;'>{$status['count']}</td>";
            echo "</tr>";
        }
        echo "</table>";
    }
    
    // 4. Diagnostic du problème Flutter
    echo "<h2>🎯 Diagnostic Flutter</h2>";
    
    $totalRequests = 0;
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM virtual_transaction_deletion_requests");
    $totalRequests = $stmt->fetch()['count'];
    
    if ($totalRequests == 0) {
        echo "<div style='background: #ffebee; padding: 15px; border-left: 4px solid #f44336; margin: 10px 0;'>";
        echo "<h3>❌ Problème identifié: Aucune demande de suppression VT</h3>";
        echo "<p>Il n'y a aucune demande de suppression de transaction virtuelle dans la base de données.</p>";
        echo "<p><strong>Solutions:</strong></p>";
        echo "<ol>";
        echo "<li>Créer des demandes de test via le script</li>";
        echo "<li>Vérifier que l'interface Flutter crée bien les demandes</li>";
        echo "<li>Vérifier la synchronisation dans DeletionService</li>";
        echo "</ol>";
        echo "</div>";
    } else {
        echo "<div style='background: #e8f5e8; padding: 15px; border-left: 4px solid #4caf50; margin: 10px 0;'>";
        echo "<h3>✅ Demandes trouvées dans la DB</h3>";
        echo "<p>Il y a <strong>$totalRequests</strong> demandes de suppression VT dans la base de données.</p>";
        echo "<p><strong>Le problème est probablement:</strong></p>";
        echo "<ol>";
        echo "<li>Le DeletionService ne synchronise pas encore les VT</li>";
        echo "<li>L'interface Flutter n'utilise pas les nouveaux getters unifiés</li>";
        echo "<li>Les filtres ne sont pas appliqués correctement</li>";
        echo "</ol>";
        echo "</div>";
    }
    
} catch (Exception $e) {
    echo "<div style='background: #ffebee; padding: 15px; border-left: 4px solid #f44336; margin: 10px 0;'>";
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
