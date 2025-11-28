<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Migration: Ajouter flotShopToShop - UCASH</title>
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
            font-size: 12px;
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
        <h1>🔄 Migration: Ajouter type 'flotShopToShop' à la table operations</h1>
        
        <div class="info">
            <h3>📋 Description</h3>
            <p>Cette migration ajoute le type <code>flotShopToShop</code> à la colonne ENUM <code>type</code> de la table <code>operations</code>.</p>
            <p><strong>Objectif:</strong> Permettre aux FLOTs (transferts de liquidité entre shops) d'être enregistrés dans la table operations au lieu d'avoir une table séparée.</p>
        </div>

<?php
require_once __DIR__ . '/config/database.php';

try {
    echo "<div class='warning'>\n";
    echo "<h3>⚠️ Vérification préliminaire</h3>\n";
    
    // Vérifier la structure actuelle de la colonne type
    $stmt = $pdo->query("
        SELECT COLUMN_TYPE 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'operations' 
          AND COLUMN_NAME = 'type'
    ");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        $currentType = $result['COLUMN_TYPE'];
        echo "<p><strong>Type ENUM actuel:</strong></p>\n";
        echo "<pre>";
        echo htmlspecialchars($currentType);
        echo "</pre>\n";
        
        // Vérifier si flotShopToShop existe déjà
        if (strpos($currentType, 'flotShopToShop') !== false) {
            echo "<div class='success'>\n";
            echo "<h3>✅ Migration déjà effectuée</h3>\n";
            echo "<p>Le type <code>flotShopToShop</code> existe déjà dans l'ENUM.</p>\n";
            echo "</div>\n";
            echo "</div>\n"; // Close warning div
        } else {
            echo "</div>\n"; // Close warning div
            
            echo "<div class='info'>\n";
            echo "<h3>🚀 Exécution de la migration...</h3>\n";
            echo "</div>\n";
            
            // Ajouter flotShopToShop à l'ENUM
            $pdo->exec("
                ALTER TABLE operations 
                MODIFY COLUMN type ENUM(
                    'transfertNational', 
                    'transfertInternationalSortant', 
                    'transfertInternationalEntrant', 
                    'depot', 
                    'retrait', 
                    'virement', 
                    'retraitMobileMoney',
                    'flotShopToShop'
                ) NOT NULL
            ");
            echo "<p>✓ Type <code>flotShopToShop</code> ajouté à l'ENUM</p>\n";
            
            echo "<div class='success'>\n";
            echo "<h3>✅ Migration réussie!</h3>\n";
            echo "<p>La table <code>operations</code> a été modifiée avec succès.</p>\n";
            echo "<p>Les FLOTs peuvent maintenant être enregistrés avec le type <code>flotShopToShop</code>.</p>\n";
            echo "</div>\n";
            
            // Vérifier le résultat
            $stmt = $pdo->query("
                SELECT COLUMN_TYPE 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'operations' 
                  AND COLUMN_NAME = 'type'
            ");
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($result) {
                echo "<div class='info'>\n";
                echo "<h3>📊 Nouveau type ENUM:</h3>\n";
                echo "<pre>";
                echo htmlspecialchars($result['COLUMN_TYPE']);
                echo "</pre>\n";
                echo "</div>\n";
            }
        }
    } else {
        echo "<div class='error'>\n";
        echo "<h3>❌ Erreur</h3>\n";
        echo "<p>La colonne <code>type</code> n'a pas été trouvée dans la table operations.</p>\n";
        echo "</div>\n";
    }
    
    // Afficher des exemples de FLOTs si ils existent
    echo "<div class='info'>\n";
    echo "<h3>📊 FLOTs existants dans la base</h3>\n";
    $stmt = $pdo->query("
        SELECT COUNT(*) as count 
        FROM operations 
        WHERE type = 'flotShopToShop'
    ");
    $flotCount = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p>Nombre de FLOTs enregistrés: <strong>{$flotCount['count']}</strong></p>\n";
    
    if ($flotCount['count'] > 0) {
        $stmt = $pdo->query("
            SELECT code_ops, shop_source_designation, shop_destination_designation, 
                   montant_net, devise, statut, created_at
            FROM operations 
            WHERE type = 'flotShopToShop'
            ORDER BY created_at DESC
            LIMIT 5
        ");
        $flots = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo "<p><strong>5 derniers FLOTs:</strong></p>\n";
        echo "<pre>";
        foreach ($flots as $flot) {
            echo "Code: {$flot['code_ops']}\n";
            echo "  De: {$flot['shop_source_designation']}\n";
            echo "  Vers: {$flot['shop_destination_designation']}\n";
            echo "  Montant: {$flot['montant_net']} {$flot['devise']}\n";
            echo "  Statut: {$flot['statut']}\n";
            echo "  Date: {$flot['created_at']}\n";
            echo "---\n";
        }
        echo "</pre>\n";
    }
    echo "</div>\n";
    
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
                <li>Les FLOTs avec <code>type = flotShopToShop</code> sont des transferts de liquidité entre shops</li>
                <li>La commission des FLOTs est toujours 0 (montant_brut = montant_net)</li>
                <li>Les FLOTs sont synchronisés via le même système que les autres opérations</li>
                <li>Cette modification est rétrocompatible</li>
            </ul>
        </div>
        
        <div class="warning">
            <h3>⚠️ Important pour la synchronisation</h3>
            <p>Après cette migration, assurez-vous que:</p>
            <ul>
                <li>Le fichier <code>server/api/sync/operations/upload.php</code> inclut <code>'flotShopToShop'</code> dans le tableau de types (index 7)</li>
                <li>Le modèle Flutter <code>OperationType</code> inclut <code>flotShopToShop</code> à l'index 7</li>
                <li>Les deux sont alignés pour éviter les erreurs de synchronisation</li>
            </ul>
        </div>
        
        <a href="init_step_by_step.php" class="btn">← Retour à l'initialisation</a>
    </div>
</body>
</html>
