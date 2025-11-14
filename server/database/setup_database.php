<?php
// Script pour vérifier l'état de la base de données et créer/migrer les tables
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../classes/Database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo "=== Vérification et mise à jour de la base de données ===\n\n";
    
    // Vérifier si la table operations existe
    $checkTable = $db->query("SHOW TABLES LIKE 'operations'")->fetch();
    
    if (!$checkTable) {
        echo "⚠️  La table 'operations' n'existe pas. Création des tables...\n\n";
        
        // Lire et exécuter sync_tables.sql
        $sqlFile = __DIR__ . '/sync_tables.sql';
        if (!file_exists($sqlFile)) {
            throw new Exception("Fichier sync_tables.sql introuvable");
        }
        
        $sql = file_get_contents($sqlFile);
        
        // Séparer les commandes SQL
        $statements = array_filter(
            array_map('trim', explode(';', $sql)),
            function($stmt) {
                return !empty($stmt) && 
                       !preg_match('/^--/', $stmt) && 
                       !preg_match('/^DROP TRIGGER/', $stmt);
            }
        );
        
        $count = 0;
        foreach ($statements as $statement) {
            if (empty(trim($statement))) continue;
            
            try {
                $db->exec($statement);
                $count++;
            } catch (PDOException $e) {
                // Ignorer les erreurs de déclencheurs et triggers
                if (strpos($e->getMessage(), 'Trigger') === false && 
                    strpos($e->getMessage(), 'already exists') === false) {
                    echo "⚠️  Avertissement: {$e->getMessage()}\n";
                }
            }
        }
        
        echo "✅ {$count} commandes SQL exécutées\n\n";
        
        // Vérifier à nouveau
        $checkTable = $db->query("SHOW TABLES LIKE 'operations'")->fetch();
        if (!$checkTable) {
            throw new Exception("Échec de la création de la table operations");
        }
        
        echo "✅ Tables créées avec succès (y compris 'virement' dans l'ENUM)\n\n";
    } else {
        echo "✅ La table 'operations' existe déjà\n\n";
        
        // Vérifier si 'virement' est déjà dans l'ENUM
        $result = $db->query("
            SELECT COLUMN_TYPE 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = 'ucash_db'
            AND TABLE_NAME = 'operations' 
            AND COLUMN_NAME = 'type'
        ")->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            echo "Type actuel: {$result['COLUMN_TYPE']}\n\n";
            
            if (strpos($result['COLUMN_TYPE'], 'virement') === false) {
                echo "⚠️  'virement' n'est pas dans l'ENUM. Ajout...\n";
                
                $db->exec("
                    ALTER TABLE operations 
                    MODIFY COLUMN type ENUM('depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'virement') NOT NULL
                ");
                
                echo "✅ 'virement' ajouté à l'ENUM avec succès\n\n";
            } else {
                echo "✅ 'virement' est déjà présent dans l'ENUM\n\n";
            }
        }
    }
    
    // Afficher un résumé
    echo "=== Résumé de la base de données ===\n";
    $tables = $db->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    echo "Tables présentes (" . count($tables) . "):\n";
    foreach ($tables as $table) {
        echo "  - $table\n";
    }
    
    echo "\n=== Mise à jour terminée ===\n";
    
} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    exit(1);
}
?>
