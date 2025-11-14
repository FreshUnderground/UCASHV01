<?php
require_once __DIR__ . '/../config/database.php';

echo "<h2>Vérification des Agents</h2>\n";

try {
    // Vérifier les agents
    $stmt = $pdo->query("SELECT id, username, nom, shop_id, role, is_active, created_at FROM agents ORDER BY id");
    $agents = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Agents dans la base (" . count($agents) . " trouvés):</h3>\n";
    if (count($agents) > 0) {
        echo "<table border='1' style='border-collapse: collapse;'>\n";
        echo "<tr><th>ID</th><th>Username</th><th>Nom</th><th>Shop ID</th><th>Role</th><th>Active</th><th>Created</th></tr>\n";
        foreach ($agents as $agent) {
            echo "<tr>";
            echo "<td>{$agent['id']}</td>";
            echo "<td>{$agent['username']}</td>";
            echo "<td>" . ($agent['nom'] ?? 'N/A') . "</td>";
            echo "<td>{$agent['shop_id']}</td>";
            echo "<td>{$agent['role']}</td>";
            echo "<td>" . ($agent['is_active'] ? 'Oui' : 'Non') . "</td>";
            echo "<td>{$agent['created_at']}</td>";
            echo "</tr>\n";
        }
        echo "</table>\n";
    } else {
        echo "<p style='color: red;'><strong>❌ Aucun agent trouvé dans la base de données!</strong></p>\n";
        echo "<p><em>C'est pourquoi la synchronisation ne trouve aucun agent.</em></p>\n";
    }
    
    // Vérifier les shops
    $stmt = $pdo->query("SELECT id, designation FROM shops ORDER BY id");
    $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<h3>Shops disponibles (" . count($shops) . "):</h3>\n";
    if (count($shops) > 0) {
        echo "<ul>\n";
        foreach ($shops as $shop) {
            echo "<li>ID {$shop['id']}: {$shop['designation']}</li>\n";
        }
        echo "</ul>\n";
    }
    
    echo "<hr>\n";
    echo "<h3>Solution:</h3>\n";
    echo "<p>Il faut créer des agents dans la base MySQL. Vous pouvez:</p>\n";
    echo "<ol>\n";
    echo "<li>Utiliser l'interface admin pour créer des agents</li>\n";
    echo "<li>OU uploader les agents locaux depuis Flutter vers MySQL (sync)</li>\n";
    echo "<li>OU exécuter un script SQL pour créer un agent test</li>\n";
    echo "</ol>\n";
    
    echo "<h4>Script SQL pour créer un agent test:</h4>\n";
    echo "<pre>\n";
    echo "INSERT INTO agents (username, password, nom, shop_id, role, is_active, created_at, last_modified_at, last_modified_by)\n";
    echo "VALUES ('agent1', 'password123', 'Agent Test', 1, 'AGENT', 1, NOW(), NOW(), 'admin');\n";
    echo "</pre>\n";
    
} catch (Exception $e) {
    echo "<p style='color: red;'>Erreur: " . $e->getMessage() . "</p>\n";
}
?>
