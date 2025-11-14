<?php
header('Content-Type: text/html; charset=UTF-8');
require_once __DIR__ . '/../config/database.php';

$action = $_GET['action'] ?? 'check';

try {
    if ($action === 'check_shops') {
        // Vérifier les shops
        $stmt = $pdo->query("SELECT id, designation, localisation FROM shops ORDER BY id");
        $shops = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<div class='success'>\n";
        echo "<h3>📊 Shops Disponibles (" . count($shops) . " trouvés):</h3>\n";
        
        if (count($shops) > 0) {
            echo "<table>\n";
            echo "<tr><th>ID</th><th>Designation</th><th>Localisation</th></tr>\n";
            foreach ($shops as $shop) {
                echo "<tr>";
                echo "<td>{$shop['id']}</td>";
                echo "<td>{$shop['designation']}</td>";
                echo "<td>{$shop['localisation']}</td>";
                echo "</tr>\n";
            }
            echo "</table>\n";
            echo "<p><strong>✅ Vous pouvez créer un agent lié à l'un de ces shops.</strong></p>\n";
        } else {
            echo "<p style='color: red;'><strong>❌ Aucun shop trouvé!</strong></p>\n";
            echo "<p><em>Créez d'abord un shop avant de créer un agent.</em></p>\n";
        }
        echo "</div>\n";
        
    } elseif ($action === 'create') {
        // Vérifier qu'un shop existe
        $stmt = $pdo->query("SELECT id FROM shops ORDER BY id LIMIT 1");
        $shop = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$shop) {
            throw new Exception("Aucun shop disponible. Créez d'abord un shop!");
        }
        
        $shopId = $shop['id'];
        
        // Vérifier si l'agent existe déjà
        $stmt = $pdo->prepare("SELECT id FROM agents WHERE username = :username");
        $stmt->execute([':username' => 'agent1']);
        $existing = $stmt->fetch();
        
        if ($existing) {
            echo "<div class='warning'>\n";
            echo "<h3>⚠️ Agent déjà existant</h3>\n";
            echo "<p>L'agent 'agent1' existe déjà (ID: {$existing['id']})</p>\n";
            echo "</div>\n";
        } else {
            // Créer l'agent
            $stmt = $pdo->prepare("
                INSERT INTO agents (
                    username, password, nom, shop_id, role, is_active,
                    created_at, last_modified_at, last_modified_by,
                    is_synced, synced_at
                ) VALUES (
                    :username, :password, :nom, :shop_id, :role, :is_active,
                    NOW(), NOW(), :last_modified_by,
                    1, NOW()
                )
            ");
            
            $stmt->execute([
                ':username' => 'agent1',
                ':password' => 'password123',
                ':nom' => 'Agent Test',
                ':shop_id' => $shopId,
                ':role' => 'AGENT',
                ':is_active' => 1,
                ':last_modified_by' => 'admin'
            ]);
            
            $agentId = $pdo->lastInsertId();
            
            echo "<div class='success'>\n";
            echo "<h3>✅ Agent créé avec succès!</h3>\n";
            echo "<ul>\n";
            echo "<li><strong>ID:</strong> $agentId</li>\n";
            echo "<li><strong>Username:</strong> agent1</li>\n";
            echo "<li><strong>Password:</strong> password123</li>\n";
            echo "<li><strong>Nom:</strong> Agent Test</li>\n";
            echo "<li><strong>Shop ID:</strong> $shopId</li>\n";
            echo "<li><strong>Role:</strong> AGENT</li>\n";
            echo "</ul>\n";
            echo "</div>\n";
        }
        
        // Afficher tous les agents
        $stmt = $pdo->query("
            SELECT a.id, a.username, a.nom, a.shop_id, s.designation as shop_name, a.role, a.is_active 
            FROM agents a
            LEFT JOIN shops s ON a.shop_id = s.id
            ORDER BY a.id
        ");
        $agents = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<div class='info'>\n";
        echo "<h3>📋 Tous les Agents (" . count($agents) . "):</h3>\n";
        echo "<table>\n";
        echo "<tr><th>ID</th><th>Username</th><th>Nom</th><th>Shop</th><th>Role</th><th>Active</th></tr>\n";
        foreach ($agents as $agent) {
            $activeIcon = $agent['is_active'] ? '✅' : '❌';
            echo "<tr>";
            echo "<td>{$agent['id']}</td>";
            echo "<td>{$agent['username']}</td>";
            echo "<td>{$agent['nom']}</td>";
            echo "<td>{$agent['shop_name']} (ID: {$agent['shop_id']})</td>";
            echo "<td>{$agent['role']}</td>";
            echo "<td>$activeIcon</td>";
            echo "</tr>\n";
        }
        echo "</table>\n";
        echo "</div>\n";
        
        echo "<div class='success'>\n";
        echo "<h3>🔄 Prochaine étape:</h3>\n";
        echo "<ol>\n";
        echo "<li>Ouvrez votre application Flutter</li>\n";
        echo "<li>Allez dans Synchronisation</li>\n";
        echo "<li>Cliquez sur 'Synchroniser maintenant'</li>\n";
        echo "<li>Les agents devraient maintenant être téléchargés!</li>\n";
        echo "</ol>\n";
        echo "</div>\n";
        
    } else {
        echo "<div class='error'>Action inconnue: $action</div>\n";
    }
    
} catch (Exception $e) {
    echo "<div class='error'>\n";
    echo "<h3>❌ Erreur</h3>\n";
    echo "<p>" . htmlspecialchars($e->getMessage()) . "</p>\n";
    echo "</div>\n";
}
?>
