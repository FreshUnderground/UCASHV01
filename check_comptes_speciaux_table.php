<?php
/**
 * Script pour vérifier la structure de la table comptes_speciaux
 */

require_once __DIR__ . '/server/config/database.php';
require_once __DIR__ . '/server/classes/Database.php';

echo "🔍 Vérification de la table comptes_speciaux\n\n";

try {
    $db = Database::getInstance()->getConnection();
    echo "✅ Connexion à la base de données réussie\n\n";
    
    // Vérifier si la table existe
    $stmt = $db->query("SHOW TABLES LIKE 'comptes_speciaux'");
    $tableExists = $stmt->fetch();
    
    if (!$tableExists) {
        echo "❌ La table 'comptes_speciaux' n'existe pas!\n";
        echo "📋 Tables existantes:\n";
        $stmt = $db->query("SHOW TABLES");
        while ($row = $stmt->fetch()) {
            echo "   - " . $row[array_key_first($row)] . "\n";
        }
        exit(1);
    }
    
    echo "✅ La table 'comptes_speciaux' existe\n\n";
    
    // Afficher la structure de la table
    echo "📋 Structure de la table:\n";
    $stmt = $db->query("DESCRIBE comptes_speciaux");
    $columns = $stmt->fetchAll();
    
    printf("%-25s %-20s %-8s %-8s\n", "Colonne", "Type", "Null", "Défaut");
    echo str_repeat("-", 80) . "\n";
    
    foreach ($columns as $col) {
        printf("%-25s %-20s %-8s %-8s\n", 
            $col['Field'], 
            $col['Type'], 
            $col['Null'], 
            $col['Default'] ?? 'NULL'
        );
    }
    
    // Compter le nombre d'enregistrements
    echo "\n📊 Statistiques:\n";
    $stmt = $db->query("SELECT COUNT(*) as total FROM comptes_speciaux");
    $count = $stmt->fetch()['total'];
    echo "   Total d'enregistrements: $count\n";
    
    // Afficher quelques exemples
    if ($count > 0) {
        echo "\n📄 Exemples d'enregistrements (max 5):\n";
        $stmt = $db->query("SELECT * FROM comptes_speciaux ORDER BY id DESC LIMIT 5");
        $examples = $stmt->fetchAll();
        
        foreach ($examples as $example) {
            echo "   ID {$example['id']}: {$example['type']} - {$example['type_transaction']} - {$example['montant']}€\n";
        }
    }
    
    echo "\n✅ Vérification terminée avec succès\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    exit(1);
}
?>
