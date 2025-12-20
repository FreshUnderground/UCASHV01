<?php
/**
 * Script de vérification et création de la table triangular_debt_settlements
 */

require_once '../config/database.php';

echo "<h2>Vérification de la table triangular_debt_settlements</h2>\n\n";

try {
    // 1. Vérifier si la table existe
    $checkTable = $pdo->query("SHOW TABLES LIKE 'triangular_debt_settlements'");
    $tableExists = $checkTable->rowCount() > 0;
    
    if ($tableExists) {
        echo "✅ La table 'triangular_debt_settlements' existe déjà.\n\n";
        
        // Afficher la structure
        $structure = $pdo->query("DESCRIBE triangular_debt_settlements");
        echo "<h3>Structure de la table:</h3>\n";
        echo "<pre>";
        while ($row = $structure->fetch(PDO::FETCH_ASSOC)) {
            printf("%-30s %-20s %-10s %-10s\n", 
                $row['Field'], 
                $row['Type'], 
                $row['Null'], 
                $row['Key']
            );
        }
        echo "</pre>\n\n";
        
        // Compter les enregistrements
        $count = $pdo->query("SELECT COUNT(*) FROM triangular_debt_settlements")->fetchColumn();
        echo "📊 Nombre d'enregistrements: $count\n\n";
        
        // Afficher les derniers enregistrements
        if ($count > 0) {
            echo "<h3>Derniers règlements:</h3>\n";
            $stmt = $pdo->query("SELECT * FROM triangular_debt_settlements ORDER BY date_reglement DESC LIMIT 5");
            echo "<pre>";
            while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
                print_r($row);
                echo "\n---\n";
            }
            echo "</pre>\n";
        }
    } else {
        echo "❌ La table 'triangular_debt_settlements' n'existe pas.\n\n";
        echo "📝 Création de la table...\n\n";
        
        // Lire et exécuter le script SQL
        $sqlFile = __DIR__ . '/../database/create_triangular_debt_settlement_table.sql';
        if (file_exists($sqlFile)) {
            $sql = file_get_contents($sqlFile);
            $pdo->exec($sql);
            echo "✅ Table créée avec succès!\n\n";
        } else {
            echo "⚠️ Fichier SQL introuvable: $sqlFile\n";
            echo "📝 Veuillez exécuter manuellement le script:\n";
            echo "database/create_triangular_debt_settlement_table.sql\n";
        }
    }
    
    echo "\n<h3>Test des endpoints API:</h3>\n";
    echo "Upload: <a href='/server/api/sync/triangular_debt_settlements/upload.php'>/server/api/sync/triangular_debt_settlements/upload.php</a>\n";
    echo "Changes: <a href='/server/api/sync/triangular_debt_settlements/changes.php'>/server/api/sync/triangular_debt_settlements/changes.php</a>\n";
    
} catch (PDOException $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}
?>
