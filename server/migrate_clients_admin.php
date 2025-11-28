<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Migration: Clients Admin - UCASH</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .success {
            background: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 5px;
            border-left: 5px solid #28a745;
            margin: 15px 0;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 5px;
            border-left: 5px solid #dc3545;
            margin: 15px 0;
        }
        .warning {
            background: #fff3cd;
            color: #856404;
            padding: 15px;
            border-radius: 5px;
            border-left: 5px solid #ffc107;
            margin: 15px 0;
        }
        .info {
            background: #d1ecf1;
            color: #0c5460;
            padding: 15px;
            border-radius: 5px;
            border-left: 5px solid #17a2b8;
            margin: 15px 0;
        }
        pre {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin: 10px 5px;
        }
        .btn:hover {
            background: #2980b9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔄 Migration: Permettre shop_id NULL pour clients admin</h1>
        
        <div class="info">
            <h3>📋 Description</h3>
            <p>Cette migration modifie la table <code>clients</code> pour permettre aux administrateurs de créer des clients globaux (sans shop spécifique).</p>
            <p><strong>Changement:</strong> La colonne <code>shop_id</code> acceptera désormais les valeurs NULL.</p>
        </div>

<?php
require_once __DIR__ . '/config/database.php';

try {
    echo "<div class='warning'>\n";
    echo "<h3>⚠️ Vérification préliminaire</h3>\n";
    
    // Vérifier la structure actuelle
    $stmt = $pdo->query("DESCRIBE clients");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $shopIdColumn = null;
    foreach ($columns as $column) {
        if ($column['Field'] === 'shop_id') {
            $shopIdColumn = $column;
            break;
        }
    }
    
    if ($shopIdColumn) {
        echo "<p><strong>Structure actuelle de shop_id:</strong></p>\n";
        echo "<pre>";
        print_r($shopIdColumn);
        echo "</pre>\n";
        
        if ($shopIdColumn['Null'] === 'YES') {
            echo "<div class='success'>\n";
            echo "<h3>✅ Migration déjà effectuée</h3>\n";
            echo "<p>La colonne <code>shop_id</code> accepte déjà les valeurs NULL.</p>\n";
            echo "</div>\n";
            echo "</div>\n"; // Close warning div
        } else {
            echo "</div>\n"; // Close warning div
            
            echo "<div class='info'>\n";
            echo "<h3>🚀 Exécution de la migration...</h3>\n";
            echo "</div>\n";
            
            // Désactiver foreign keys
            $pdo->exec("SET FOREIGN_KEY_CHECKS = 0");
            echo "<p>✓ Foreign keys désactivées temporairement</p>\n";
            
            // Modifier la colonne
            $pdo->exec("ALTER TABLE clients MODIFY COLUMN shop_id INT NULL COMMENT 'ID du shop de création (NULL pour clients admin globaux)'");
            echo "<p>✓ Colonne shop_id modifiée pour accepter NULL</p>\n";
            
            // Réactiver foreign keys
            $pdo->exec("SET FOREIGN_KEY_CHECKS = 1");
            echo "<p>✓ Foreign keys réactivées</p>\n";
            
            echo "<div class='success'>\n";
            echo "<h3>✅ Migration réussie!</h3>\n";
            echo "<p>La table <code>clients</code> a été modifiée avec succès.</p>\n";
            echo "<p>Les administrateurs peuvent maintenant créer des clients sans shop spécifique (shop_id = NULL).</p>\n";
            echo "</div>\n";
            
            // Vérifier le résultat
            $stmt = $pdo->query("DESCRIBE clients");
            $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            foreach ($columns as $column) {
                if ($column['Field'] === 'shop_id') {
                    echo "<div class='info'>\n";
                    echo "<h3>📊 Nouvelle structure de shop_id:</h3>\n";
                    echo "<pre>";
                    print_r($column);
                    echo "</pre>\n";
                    echo "</div>\n";
                    break;
                }
            }
        }
    } else {
        echo "<div class='error'>\n";
        echo "<h3>❌ Erreur</h3>\n";
        echo "<p>La colonne <code>shop_id</code> n'a pas été trouvée dans la table clients.</p>\n";
        echo "</div>\n";
    }
    
} catch (Exception $e) {
    echo "<div class='error'>\n";
    echo "<h3>❌ Erreur durant la migration</h3>\n";
    echo "<p>" . htmlspecialchars($e->getMessage()) . "</p>\n";
    echo "</div>\n";
}
?>

        <div class="info">
            <h3>📝 Notes importantes</h3>
            <ul>
                <li>Les clients avec <code>shop_id = NULL</code> sont considérés comme des clients globaux (créés par l'admin)</li>
                <li>Les clients créés par les agents auront toujours un <code>shop_id</code> valide</li>
                <li>Cette modification est rétrocompatible et n'affecte pas les clients existants</li>
            </ul>
        </div>
        
        <a href="index.php" class="btn">← Retour au tableau de bord</a>
    </div>
</body>
</html>
