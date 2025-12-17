<?php
/**
 * Script pour créer des demandes de suppression de test
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🧪 Création de demandes de suppression de test</h1>";

try {
    // Récupérer quelques transactions virtuelles existantes
    $stmt = $pdo->query("SELECT * FROM virtual_transactions ORDER BY date_enregistrement DESC LIMIT 3");
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($transactions)) {
        echo "<div style='background: #ffebee; padding: 10px; border-left: 4px solid #f44336;'>";
        echo "<h3>❌ Aucune transaction virtuelle trouvée</h3>";
        echo "<p>Vous devez d'abord avoir des transactions virtuelles pour créer des demandes de suppression.</p>";
        echo "<p>Créez des transactions via l'application Flutter, puis revenez ici.</p>";
        echo "</div>";
        exit;
    }
    
    echo "<h2>📋 Transactions virtuelles disponibles (" . count($transactions) . ")</h2>";
    echo "<table border='1' style='border-collapse: collapse; width: 100%; margin: 10px 0;'>";
    echo "<tr><th>Référence</th><th>Montant</th><th>Client</th><th>Statut</th><th>Date</th><th>Action</th></tr>";
    
    foreach ($transactions as $tx) {
        echo "<tr>";
        echo "<td>{$tx['reference']}</td>";
        echo "<td>{$tx['montant_virtuel']} {$tx['devise']}</td>";
        echo "<td>{$tx['client_nom']}</td>";
        echo "<td>{$tx['statut']}</td>";
        echo "<td>{$tx['date_enregistrement']}</td>";
        echo "<td><a href='?create_request={$tx['reference']}' style='background: #f44336; color: white; padding: 5px 10px; text-decoration: none; border-radius: 3px;'>Créer demande suppression</a></td>";
        echo "</tr>";
    }
    echo "</table>";
    
    // Traiter la création d'une demande
    if (isset($_GET['create_request'])) {
        $reference = $_GET['create_request'];
        
        // Trouver la transaction
        $stmt = $pdo->prepare("SELECT * FROM virtual_transactions WHERE reference = ?");
        $stmt->execute([$reference]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($transaction) {
            // Vérifier si une demande existe déjà
            $checkStmt = $pdo->prepare("SELECT * FROM virtual_transaction_deletion_requests WHERE reference = ?");
            $checkStmt->execute([$reference]);
            $existingRequest = $checkStmt->fetch();
            
            if ($existingRequest) {
                echo "<div style='background: #fff3cd; padding: 10px; border-left: 4px solid #ffc107;'>";
                echo "<h3>⚠️ Demande déjà existante</h3>";
                echo "<p>Une demande de suppression existe déjà pour la transaction $reference</p>";
                echo "<p><strong>Statut actuel:</strong> {$existingRequest['statut']}</p>";
                echo "</div>";
            } else {
                // Créer la demande de suppression
                $insertStmt = $pdo->prepare("
                    INSERT INTO virtual_transaction_deletion_requests (
                        reference, virtual_transaction_id, transaction_type, montant, devise,
                        destinataire, expediteur, client_nom,
                        requested_by_admin_id, requested_by_admin_name, request_date, reason,
                        statut, created_at, last_modified_at, last_modified_by
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ");
                
                $now = date('Y-m-d H:i:s');
                $insertStmt->execute([
                    $transaction['reference'],
                    $transaction['id'],
                    'Transaction Virtuelle',
                    $transaction['montant_virtuel'],
                    $transaction['devise'],
                    $transaction['client_nom'],
                    $transaction['agent_username'],
                    $transaction['client_nom'],
                    1, // admin_id de test
                    'Admin Test',
                    $now,
                    'Demande de suppression de test créée automatiquement',
                    'en_attente',
                    $now,
                    $now,
                    'Admin Test'
                ]);
                
                echo "<div style='background: #e8f5e8; padding: 10px; border-left: 4px solid #4caf50;'>";
                echo "<h3>✅ Demande de suppression créée</h3>";
                echo "<p><strong>Référence:</strong> $reference</p>";
                echo "<p><strong>Statut:</strong> en_attente</p>";
                echo "<p>Vous pouvez maintenant tester l'API de download des demandes de suppression.</p>";
                echo "</div>";
            }
        }
    }
    
    // Afficher les demandes existantes
    echo "<h2>🗑️ Demandes de suppression existantes</h2>";
    $stmt = $pdo->query("SELECT * FROM virtual_transaction_deletion_requests ORDER BY request_date DESC");
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($requests)) {
        echo "<p>Aucune demande de suppression trouvée. Cliquez sur 'Créer demande suppression' ci-dessus pour en créer une.</p>";
    } else {
        echo "<table border='1' style='border-collapse: collapse; width: 100%; margin: 10px 0;'>";
        echo "<tr><th>Référence</th><th>Montant</th><th>Demandé par</th><th>Statut</th><th>Date demande</th></tr>";
        
        foreach ($requests as $req) {
            $statusColor = match($req['statut']) {
                'en_attente' => '#ffc107',
                'admin_validee' => '#17a2b8',
                'agent_validee' => '#28a745',
                'refusee' => '#dc3545',
                default => '#6c757d'
            };
            
            echo "<tr>";
            echo "<td>{$req['reference']}</td>";
            echo "<td>{$req['montant']} {$req['devise']}</td>";
            echo "<td>{$req['requested_by_admin_name']}</td>";
            echo "<td><span style='background: $statusColor; color: white; padding: 2px 8px; border-radius: 3px;'>{$req['statut']}</span></td>";
            echo "<td>{$req['request_date']}</td>";
            echo "</tr>";
        }
        echo "</table>";
        
        echo "<h3>🔗 Tester l'API maintenant</h3>";
        echo "<p>Maintenant que vous avez des demandes de suppression, testez l'API :</p>";
        echo "<p><a href='/UCASHV01/server/api/sync/virtual_transaction_deletion_requests/download.php' target='_blank' style='background: #007bff; color: white; padding: 8px 15px; text-decoration: none; border-radius: 5px;'>Tester API Download</a></p>";
    }
    
} catch (Exception $e) {
    echo "<div style='background: #ffebee; padding: 10px; border-left: 4px solid #f44336;'>";
    echo "<h3>❌ Erreur</h3>";
    echo "<p><strong>Message:</strong> " . $e->getMessage() . "</p>";
    echo "</div>";
}
?>

<style>
body { font-family: Arial, sans-serif; margin: 20px; }
table { margin: 10px 0; }
th, td { padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
</style>
