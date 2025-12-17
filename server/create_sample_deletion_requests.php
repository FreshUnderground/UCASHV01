<?php
/**
 * Script pour créer des demandes de suppression d'exemple à partir des transactions existantes
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🧪 Création de demandes de suppression d'exemple</h1>";

try {
    // Sélectionner quelques transactions pour créer des demandes de suppression
    $selectedReferences = [
        '0922 f31871',  // Transaction validée de Luck
        '1526 h08871',  // Transaction validée de luck  
        '0932 g00360',  // Transaction en attente
        'clf85d1mulg',  // Transaction en attente
        '0850 h30260'   // Transaction validée de julien
    ];
    
    echo "<h2>📋 Création de demandes de suppression pour les transactions sélectionnées</h2>";
    
    $created = 0;
    $skipped = 0;
    
    foreach ($selectedReferences as $reference) {
        // Récupérer la transaction
        $stmt = $pdo->prepare("SELECT * FROM virtual_transactions WHERE reference = ?");
        $stmt->execute([$reference]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$transaction) {
            echo "<p>⚠️ Transaction '$reference' non trouvée</p>";
            continue;
        }
        
        // Vérifier si une demande existe déjà
        $checkStmt = $pdo->prepare("SELECT * FROM virtual_transaction_deletion_requests WHERE reference = ?");
        $checkStmt->execute([$reference]);
        $existingRequest = $checkStmt->fetch();
        
        if ($existingRequest) {
            echo "<p>⏭️ Demande déjà existante pour '$reference' (statut: {$existingRequest['statut']})</p>";
            $skipped++;
            continue;
        }
        
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
        $reason = "Demande de suppression automatique - Transaction: {$transaction['reference']} ({$transaction['statut']})";
        
        $insertStmt->execute([
            $transaction['reference'],
            $transaction['id'],
            'Transaction Virtuelle',
            $transaction['montant_virtuel'],
            $transaction['devise'],
            $transaction['client_nom'] ?? 'N/A',
            $transaction['agent_username'],
            $transaction['client_nom'],
            1, // admin_id de test
            'Admin Test',
            $now,
            $reason,
            'en_attente',
            $now,
            $now,
            'System Auto'
        ]);
        
        echo "<p>✅ Demande créée pour '$reference' - {$transaction['montant_virtuel']} {$transaction['devise']} ({$transaction['statut']})</p>";
        $created++;
    }
    
    echo "<h2>📊 Résumé</h2>";
    echo "<p><strong>Demandes créées:</strong> $created</p>";
    echo "<p><strong>Demandes ignorées (déjà existantes):</strong> $skipped</p>";
    
    // Afficher toutes les demandes existantes
    echo "<h2>🗑️ Toutes les demandes de suppression</h2>";
    $stmt = $pdo->query("
        SELECT vdr.*, vt.statut as transaction_statut 
        FROM virtual_transaction_deletion_requests vdr
        LEFT JOIN virtual_transactions vt ON vdr.reference = vt.reference
        ORDER BY vdr.request_date DESC
    ");
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($requests)) {
        echo "<p>Aucune demande de suppression trouvée.</p>";
    } else {
        echo "<table border='1' style='border-collapse: collapse; width: 100%; margin: 10px 0;'>";
        echo "<tr>";
        echo "<th>Référence</th>";
        echo "<th>Montant</th>";
        echo "<th>Client</th>";
        echo "<th>Statut Transaction</th>";
        echo "<th>Statut Demande</th>";
        echo "<th>Demandé par</th>";
        echo "<th>Date</th>";
        echo "</tr>";
        
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
            echo "<td>{$req['client_nom']}</td>";
            echo "<td>{$req['transaction_statut']}</td>";
            echo "<td><span style='background: $statusColor; color: white; padding: 2px 8px; border-radius: 3px;'>{$req['statut']}</span></td>";
            echo "<td>{$req['requested_by_admin_name']}</td>";
            echo "<td>{$req['request_date']}</td>";
            echo "</tr>";
        }
        echo "</table>";
    }
    
    // Liens pour tester les APIs
    echo "<h2>🔗 Tester les APIs maintenant</h2>";
    echo "<div style='margin: 20px 0;'>";
    echo "<a href='/UCASHV01/server/api/sync/virtual_transaction_deletion_requests/download.php' target='_blank' style='background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 5px;'>📥 API Download Demandes</a>";
    echo "<a href='/UCASHV01/server/api/sync/virtual_transactions/changes.php' target='_blank' style='background: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 5px;'>📋 API Transactions Principales</a>";
    echo "</div>";
    
    echo "<h2>🎯 Prochaines étapes</h2>";
    echo "<ol>";
    echo "<li><strong>Tester l'API de download</strong> - Vous devriez maintenant voir les demandes de suppression</li>";
    echo "<li><strong>Créer le service Flutter</strong> - VirtualTransactionDeletionService</li>";
    echo "<li><strong>Intégrer dans l'UI</strong> - Ajouter les boutons de suppression</li>";
    echo "<li><strong>Tester le workflow complet</strong> - Admin → Agent → Suppression</li>";
    echo "</ol>";
    
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
</style>
