<?php
/**
 * Script pour forcer la création de demandes de suppression VT et diagnostiquer le problème
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🔧 Diagnostic et création forcée de demandes VT</h1>";

try {
    // 1. Vérifier l'état actuel
    echo "<h2>📊 État actuel de la base de données</h2>";
    
    // Vérifier les tables
    $stmt = $pdo->query("SHOW TABLES LIKE 'virtual_transaction_deletion_requests'");
    $tableExists = $stmt->fetch();
    
    if (!$tableExists) {
        echo "<p style='color: red;'>❌ Table virtual_transaction_deletion_requests n'existe pas!</p>";
        echo "<p>Exécutez d'abord: <a href='/UCASHV01/server/setup_virtual_transaction_deletion.php'>Setup Tables</a></p>";
        exit;
    }
    
    // Compter les demandes existantes
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM virtual_transaction_deletion_requests");
    $existingCount = $stmt->fetch()['count'];
    echo "<p>📋 Demandes VT existantes: <strong>$existingCount</strong></p>";
    
    // Compter les transactions virtuelles disponibles
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM virtual_transactions");
    $vtCount = $stmt->fetch()['count'];
    echo "<p>💰 Transactions virtuelles disponibles: <strong>$vtCount</strong></p>";
    
    if ($vtCount == 0) {
        echo "<p style='color: red;'>❌ Aucune transaction virtuelle trouvée! Créez d'abord des transactions via l'app Flutter.</p>";
        exit;
    }
    
    // 2. Créer des demandes de suppression forcées
    echo "<h2>🚀 Création forcée de demandes de suppression VT</h2>";
    
    // Sélectionner les 5 premières transactions virtuelles
    $stmt = $pdo->query("
        SELECT * FROM virtual_transactions 
        WHERE reference NOT IN (
            SELECT reference FROM virtual_transaction_deletion_requests
        )
        ORDER BY date_enregistrement DESC 
        LIMIT 5
    ");
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($transactions)) {
        echo "<p>⚠️ Toutes les transactions ont déjà des demandes de suppression.</p>";
    } else {
        $created = 0;
        foreach ($transactions as $tx) {
            $now = date('Y-m-d H:i:s');
            
            $insertStmt = $pdo->prepare("
                INSERT INTO virtual_transaction_deletion_requests (
                    reference, virtual_transaction_id, transaction_type, montant, devise,
                    destinataire, expediteur, client_nom,
                    requested_by_admin_id, requested_by_admin_name, request_date, reason,
                    statut, created_at, last_modified_at, last_modified_by, is_synced
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            $insertStmt->execute([
                $tx['reference'],
                $tx['id'],
                'Transaction Virtuelle',
                $tx['montant_virtuel'],
                $tx['devise'],
                $tx['client_nom'] ?? 'N/A',
                $tx['agent_username'],
                $tx['client_nom'],
                1, // admin_id
                'Admin Test',
                $now,
                'Demande créée automatiquement pour test - ' . $tx['reference'],
                'en_attente',
                $now,
                $now,
                'System Auto',
                0 // not synced
            ]);
            
            echo "<p>✅ Demande créée: <strong>{$tx['reference']}</strong> - {$tx['montant_virtuel']} {$tx['devise']}</p>";
            $created++;
        }
        
        echo "<p style='background: #e8f5e8; padding: 10px; border-left: 4px solid #4caf50;'>";
        echo "<strong>✅ $created demandes de suppression VT créées avec succès!</strong>";
        echo "</p>";
    }
    
    // 3. Vérifier l'API de download
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
        
        if (isset($data['data']) && is_array($data['data']) && count($data['data']) > 0) {
            echo "<h3>📋 Premières demandes retournées:</h3>";
            echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
            echo "<tr><th>Reference</th><th>Montant</th><th>Statut</th><th>Demandé par</th><th>Date</th></tr>";
            
            foreach (array_slice($data['data'], 0, 3) as $req) {
                echo "<tr>";
                echo "<td>{$req['reference']}</td>";
                echo "<td>{$req['montant']} {$req['devise']}</td>";
                echo "<td>{$req['statut']}</td>";
                echo "<td>{$req['requested_by_admin_name']}</td>";
                echo "<td>{$req['request_date']}</td>";
                echo "</tr>";
            }
            echo "</table>";
        }
    } else {
        echo "<p><strong>❌ API Response:</strong> Erreur de connexion</p>";
    }
    
    // 4. Instructions pour Flutter
    echo "<h2>📱 Instructions pour Flutter</h2>";
    echo "<div style='background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107;'>";
    echo "<h3>🔧 Problème identifié</h3>";
    echo "<p>Les demandes VT existent maintenant dans la DB, mais l'interface Flutter n'utilise probablement pas les nouveaux getters unifiés.</p>";
    echo "<p><strong>Solutions:</strong></p>";
    echo "<ol>";
    echo "<li><strong>Vérifier que l'interface utilise:</strong> <code>DeletionService.instance.getAllAdminPendingRequests()</code></li>";
    echo "<li><strong>Ou utiliser le filtre VT:</strong> <code>getAllAdminPendingRequests(type: DeletionType.virtualTransactions)</code></li>";
    echo "<li><strong>Forcer la synchronisation:</strong> Appeler <code>DeletionService.instance.syncAll()</code></li>";
    echo "<li><strong>Redémarrer l'app Flutter</strong> pour que le service se synchronise</li>";
    echo "</ol>";
    echo "</div>";
    
    // 5. Résumé final
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM virtual_transaction_deletion_requests");
    $finalCount = $stmt->fetch()['count'];
    
    echo "<h2>🎯 Résumé final</h2>";
    echo "<p><strong>Total demandes VT dans la DB:</strong> $finalCount</p>";
    echo "<p><strong>API fonctionnelle:</strong> " . ($response !== false ? "✅ Oui" : "❌ Non") . "</p>";
    echo "<p><strong>Prochaine étape:</strong> Vérifier que l'interface Flutter utilise les nouveaux getters unifiés</p>";
    
} catch (Exception $e) {
    echo "<div style='background: #ffebee; padding: 15px; border-left: 4px solid #f44336;'>";
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
</style>
