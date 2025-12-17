<?php
/**
 * Script pour diagnostiquer les validations admin des transactions virtuelles
 */

header('Content-Type: text/html; charset=utf-8');
require_once __DIR__ . '/config/database.php';

echo "<h1>🔍 Diagnostic des validations admin VT</h1>";

try {
    // 1. Vérifier toutes les demandes VT par statut
    echo "<h2>📊 État des demandes VT par statut</h2>";
    
    $stmt = $pdo->query("
        SELECT statut, COUNT(*) as count 
        FROM virtual_transaction_deletion_requests 
        GROUP BY statut 
        ORDER BY 
            CASE statut 
                WHEN 'en_attente' THEN 1 
                WHEN 'admin_validee' THEN 2 
                WHEN 'agent_validee' THEN 3 
                WHEN 'refusee' THEN 4 
                ELSE 5 
            END
    ");
    $statusCounts = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($statusCounts)) {
        echo "<p>❌ Aucune demande de suppression VT trouvée.</p>";
        echo "<p><a href='/UCASHV01/server/force_create_vt_deletion_requests.php'>Créer des demandes de test</a></p>";
        exit;
    }
    
    echo "<table border='1' style='border-collapse: collapse; margin: 10px 0;'>";
    echo "<tr><th style='padding: 8px; background: #f0f0f0;'>Statut</th><th style='padding: 8px; background: #f0f0f0;'>Nombre</th></tr>";
    foreach ($statusCounts as $status) {
        $color = match($status['statut']) {
            'en_attente' => '#ffc107',
            'admin_validee' => '#17a2b8',
            'agent_validee' => '#28a745',
            'refusee' => '#dc3545',
            default => '#6c757d'
        };
        echo "<tr>";
        echo "<td style='padding: 8px;'><span style='background: $color; color: white; padding: 2px 8px; border-radius: 3px;'>{$status['statut']}</span></td>";
        echo "<td style='padding: 8px;'>{$status['count']}</td>";
        echo "</tr>";
    }
    echo "</table>";
    
    // 2. Détail des demandes admin_validee (celles que l'agent doit voir)
    echo "<h2>🎯 Demandes validées par admin (pour l'agent)</h2>";
    
    $stmt = $pdo->query("
        SELECT vdr.*, vt.statut as transaction_statut 
        FROM virtual_transaction_deletion_requests vdr
        LEFT JOIN virtual_transactions vt ON vdr.reference = vt.reference
        WHERE vdr.statut = 'admin_validee'
        ORDER BY vdr.validation_admin_date DESC
    ");
    $adminValidatedRequests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($adminValidatedRequests)) {
        echo "<p>⚠️ Aucune demande VT validée par admin trouvée.</p>";
        echo "<p>L'agent ne voit rien car il n'y a pas de demandes au statut 'admin_validee'.</p>";
    } else {
        echo "<p>✅ <strong>{count($adminValidatedRequests)} demandes VT validées par admin</strong> (que l'agent devrait voir)</p>";
        
        echo "<table border='1' style='border-collapse: collapse; width: 100%; margin: 10px 0;'>";
        echo "<tr>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Référence</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Montant</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Client</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Demandé par</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Validé par admin</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Date validation admin</th>";
        echo "<th style='padding: 5px; background: #f0f0f0;'>Statut</th>";
        echo "</tr>";
        
        foreach ($adminValidatedRequests as $req) {
            echo "<tr>";
            echo "<td style='padding: 5px;'>{$req['reference']}</td>";
            echo "<td style='padding: 5px;'>{$req['montant']} {$req['devise']}</td>";
            echo "<td style='padding: 5px;'>{$req['client_nom']}</td>";
            echo "<td style='padding: 5px;'>{$req['requested_by_admin_name']}</td>";
            echo "<td style='padding: 5px;'><strong>{$req['validated_by_admin_name']}</strong></td>";
            echo "<td style='padding: 5px;'>{$req['validation_admin_date']}</td>";
            echo "<td style='padding: 5px;'><span style='background: #17a2b8; color: white; padding: 2px 8px; border-radius: 3px;'>{$req['statut']}</span></td>";
            echo "</tr>";
        }
        echo "</table>";
    }
    
    // 3. Tester l'API de download pour l'agent
    echo "<h2>🔗 Test API pour l'agent</h2>";
    
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
        echo "<p><strong>Total demandes dans l'API:</strong> " . (isset($data['count']) ? $data['count'] : 'N/A') . "</p>";
        
        if (isset($data['data']) && is_array($data['data'])) {
            $adminValidatedInApi = array_filter($data['data'], function($req) {
                return $req['statut'] === 'admin_validee';
            });
            
            echo "<p><strong>Demandes admin_validee dans l'API:</strong> " . count($adminValidatedInApi) . "</p>";
            
            if (count($adminValidatedInApi) > 0) {
                echo "<h3>📋 Demandes que l'agent devrait voir:</h3>";
                echo "<ul>";
                foreach ($adminValidatedInApi as $req) {
                    echo "<li><strong>{$req['reference']}</strong> - {$req['montant']} {$req['devise']} - Validé par: {$req['validated_by_admin_name']}</li>";
                }
                echo "</ul>";
            }
        }
    } else {
        echo "<p><strong>❌ API Response:</strong> Erreur de connexion</p>";
    }
    
    // 4. Diagnostic du problème
    echo "<h2>🎯 Diagnostic du problème</h2>";
    
    $totalAdminValidated = count($adminValidatedRequests);
    
    if ($totalAdminValidated == 0) {
        echo "<div style='background: #ffebee; padding: 15px; border-left: 4px solid #f44336; margin: 10px 0;'>";
        echo "<h3>❌ Problème identifié: Aucune demande VT au statut admin_validee</h3>";
        echo "<p>Les demandes VT ne passent pas au statut 'admin_validee' après validation admin.</p>";
        echo "<p><strong>Solutions:</strong></p>";
        echo "<ol>";
        echo "<li>Vérifier que la validation admin VT fonctionne correctement</li>";
        echo "<li>Vérifier l'API admin_validate.php pour les VT</li>";
        echo "<li>Vérifier la synchronisation des statuts</li>";
        echo "</ol>";
        echo "</div>";
    } else {
        echo "<div style='background: #e8f5e8; padding: 15px; border-left: 4px solid #4caf50; margin: 10px 0;'>";
        echo "<h3>✅ Demandes VT validées par admin trouvées</h3>";
        echo "<p>Il y a <strong>$totalAdminValidated</strong> demandes VT au statut 'admin_validee'.</p>";
        echo "<p><strong>Le problème est probablement:</strong></p>";
        echo "<ol>";
        echo "<li>L'interface agent ne synchronise pas les VT</li>";
        echo "<li>L'interface agent n'affiche que les opérations</li>";
        echo "<li>Les getters agent pour VT n'existent pas dans DeletionService</li>";
        echo "</ol>";
        echo "</div>";
    }
    
    // 5. Prochaines étapes
    echo "<h2>🚀 Prochaines étapes</h2>";
    echo "<ol>";
    echo "<li><strong>Ajouter les getters agent VT</strong> dans DeletionService</li>";
    echo "<li><strong>Mettre à jour l'interface agent</strong> pour afficher les VT</li>";
    echo "<li><strong>Tester le workflow complet</strong> admin → agent → suppression</li>";
    echo "</ol>";
    
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
