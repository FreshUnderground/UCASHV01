<?php
/**
 * Script d'initialisation: Système de corbeille
 * 
 * Vérifie que le système de corbeille est correctement configuré.
 */

require_once __DIR__ . '/config/database.php';

echo "🔧 Vérification du système de corbeille...\n";

try {
    $db = $pdo;
    
    // Vérifier si la table operations_corbeille existe
    $tableCheck = $db->query("SHOW TABLES LIKE 'operations_corbeille'");
    if ($tableCheck->rowCount() > 0) {
        echo "✅ Table operations_corbeille existe\n";
        
        // Vérifier la structure de la table
        $columns = $db->query("DESCRIBE operations_corbeille");
        $columnNames = [];
        while ($row = $columns->fetch(PDO::FETCH_ASSOC)) {
            $columnNames[] = $row['Field'];
        }
        
        // Vérifier les colonnes essentielles
        $requiredColumns = ['code_ops', 'deleted_at'];
        foreach ($requiredColumns as $col) {
            if (in_array($col, $columnNames)) {
                echo "✅ Colonne $col présente\n";
            } else {
                echo "❌ Colonne $col manquante\n";
            }
        }
    } else {
        echo "❌ Table operations_corbeille n'existe pas\n";
        echo "💡 Vous devez exécuter le script de migration de la base de données\n";
    }
    
    echo "\n🎉 Vérification terminée!\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    exit(1);
}
?>