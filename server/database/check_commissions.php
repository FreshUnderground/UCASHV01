<?php
header('Content-Type: text/html; charset=utf-8');

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../classes/Database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo '<div class="result success">';
    echo '<h2>📊 Commissions dans la base de données</h2>';
    
    // Récupérer toutes les commissions
    $stmt = $db->query("SELECT * FROM commissions ORDER BY type");
    $commissions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($commissions) > 0) {
        echo '<p>✅ <strong>' . count($commissions) . ' commission(s) trouvée(s)</strong></p>';
        echo '<table>';
        echo '<tr><th>ID</th><th>Type</th><th>Taux (%)</th><th>Description</th><th>Actif</th></tr>';
        foreach ($commissions as $comm) {
            $isActive = $comm['is_active'] ? '✅ Oui' : '❌ Non';
            echo "<tr>";
            echo "<td>{$comm['id']}</td>";
            echo "<td><strong>{$comm['type']}</strong></td>";
            echo "<td><strong>{$comm['taux']}%</strong></td>";
            echo "<td>{$comm['description']}</td>";
            echo "<td>{$isActive}</td>";
            echo "</tr>";
        }
        echo '</table>';
    } else {
        echo '</div><div class="result error">';
        echo '<h3>❌ AUCUNE commission trouvée!</h3>';
        echo '<p>Vous devez créer les commissions suivantes:</p>';
        echo '<ul>';
        echo '<li><strong>SORTANT</strong>: Commission pour les transferts sortants (ex: 3.5%)</li>';
        echo '<li><strong>ENTRANT</strong>: Commission pour les transferts entrants (ex: 0%)</li>';
        echo '</ul>';
        echo '<p>Utilisez la page de gestion des commissions pour les créer.</p>';
    }
    
    echo '</div>';
    
    // Vérifier aussi les taux
    echo '<div class="result success">';
    echo '<h2>💱 Taux de change dans la base de données</h2>';
    
    $stmt = $db->query("SELECT * FROM taux WHERE est_actif = 1 ORDER BY devise_cible, type");
    $taux = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($taux) > 0) {
        echo '<p>✅ <strong>' . count($taux) . ' taux actif(s) trouvé(s)</strong></p>';
        echo '<table>';
        echo '<tr><th>ID</th><th>Devise Cible</th><th>Type</th><th>Taux</th><th>Date Effet</th></tr>';
        foreach ($taux as $t) {
            echo "<tr>";
            echo "<td>{$t['id']}</td>";
            echo "<td><strong>{$t['devise_cible']}</strong></td>";
            echo "<td>{$t['type']}</td>";
            echo "<td><strong>{$t['taux']}</strong></td>";
            echo "<td>{$t['date_effet']}</td>";
            echo "</tr>";
        }
        echo '</table>';
    } else {
        echo '<p>⚠️ Aucun taux actif trouvé</p>';
    }
    
    echo '</div>';
    
} catch (Exception $e) {
    echo '<div class="result error">';
    echo '<h3>❌ Erreur</h3>';
    echo '<p>' . $e->getMessage() . '</p>';
    echo '</div>';
}
?>
