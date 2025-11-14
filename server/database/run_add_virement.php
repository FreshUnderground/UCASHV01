<?php
// Script pour exécuter la migration: ajouter 'virement' au type ENUM
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../classes/Database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo "=== Migration: Ajouter 'virement' au type ENUM ===\n\n";
    
    // Vérifier si la table existe
    $checkTable = $db->query("SHOW TABLES LIKE 'operations'")->fetch();
    
    if (!$checkTable) {
        echo "❌ ERREUR: La table 'operations' n'existe pas.\n";
        echo "   Veuillez d'abord exécuter sync_tables.sql pour créer les tables.\n";
        exit(1);
    }
    
    // Modifier la colonne type
    echo "1. Modification de la colonne 'type'...\n";
    $db->exec("
        ALTER TABLE operations 
        MODIFY COLUMN type ENUM('depot', 'retrait', 'transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'virement') NOT NULL
    ");
    echo "   ✅ Colonne 'type' modifiée avec succès\n\n";
    
    // Vérifier la modification
    echo "2. Vérification de la modification...\n";
    $result = $db->query("
        SELECT COLUMN_NAME, COLUMN_TYPE 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'ucash_db'
        AND TABLE_NAME = 'operations' 
        AND COLUMN_NAME = 'type'
    ")->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        echo "   Type actuel: {$result['COLUMN_TYPE']}\n";
        if (strpos($result['COLUMN_TYPE'], 'virement') !== false) {
            echo "   ✅ Migration réussie! 'virement' ajouté à l'ENUM\n";
        } else {
            echo "   ❌ ERREUR: 'virement' n'a pas été ajouté\n";
        }
    }
    
    echo "\n=== Migration terminée ===\n";
    
} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    exit(1);
}
?>
