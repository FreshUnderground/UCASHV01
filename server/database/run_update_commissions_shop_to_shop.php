<?php
/**
 * Script de migration pour mettre à jour la table commissions
 * Ajoute les colonnes source_shop_id et destination_shop_id pour supporter les commissions par route
 */

// Configuration
require_once __DIR__ . '/../config/database.php';

echo "Début de la migration des commissions pour le système shop-to-shop...\n";

try {
    // Début de transaction
    $pdo->beginTransaction();
    
    // Vérifier si les colonnes existent déjà
    $columns = $pdo->query("SHOW COLUMNS FROM commissions LIKE 'source_shop_id'")->fetchAll();
    if (empty($columns)) {
        echo "Ajout des colonnes source_shop_id et destination_shop_id...\n";
        
        // Ajouter les nouvelles colonnes
        $pdo->exec("
            ALTER TABLE `commissions` 
            ADD COLUMN `source_shop_id` INT(11) DEFAULT NULL COMMENT 'Source shop ID for route-specific commissions',
            ADD COLUMN `destination_shop_id` INT(11) DEFAULT NULL COMMENT 'Destination shop ID for route-specific commissions'
        ");
        
        echo "Colonnes ajoutées avec succès.\n";
    } else {
        echo "Les colonnes existent déjà, passage à l'étape suivante...\n";
    }
    
    // Ajouter les index si ils n'existent pas
    $indexes = $pdo->query("SHOW INDEX FROM commissions WHERE Key_name IN ('idx_source_shop', 'idx_destination_shop')")->fetchAll();
    if (count($indexes) < 2) {
        echo "Ajout des index pour les performances...\n";
        
        $pdo->exec("
            ALTER TABLE `commissions` 
            ADD KEY `idx_source_shop` (`source_shop_id`),
            ADD KEY `idx_destination_shop` (`destination_shop_id`)
        ");
        
        echo "Index ajoutés avec succès.\n";
    } else {
        echo "Les index existent déjà, passage à l'étape suivante...\n";
    }
    
    // Ajouter les contraintes de clé étrangère si elles n'existent pas
    $foreignKeys = $pdo->query("
        SELECT CONSTRAINT_NAME 
        FROM information_schema.KEY_COLUMN_USAGE 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'commissions' 
        AND REFERENCED_TABLE_NAME = 'shops'
        AND CONSTRAINT_NAME IN ('fk_commission_source_shop', 'fk_commission_destination_shop')
    ")->fetchAll();
    
    if (count($foreignKeys) < 2) {
        echo "Ajout des contraintes de clé étrangère...\n";
        
        // Supprimer d'abord les contraintes existantes si nécessaire
        try {
            $pdo->exec("ALTER TABLE `commissions` DROP FOREIGN KEY `fk_commission_source_shop`");
        } catch (Exception $e) {
            // La contrainte n'existe peut-être pas, c'est normal
        }
        
        try {
            $pdo->exec("ALTER TABLE `commissions` DROP FOREIGN KEY `fk_commission_destination_shop`");
        } catch (Exception $e) {
            // La contrainte n'existe peut-être pas, c'est normal
        }
        
        // Ajouter les nouvelles contraintes
        $pdo->exec("
            ALTER TABLE `commissions` 
            ADD CONSTRAINT `fk_commission_source_shop` FOREIGN KEY (`source_shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
            ADD CONSTRAINT `fk_commission_destination_shop` FOREIGN KEY (`destination_shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE
        ");
        
        echo "Contraintes de clé étrangère ajoutées avec succès.\n";
    } else {
        echo "Les contraintes de clé étrangère existent déjà, passage à l'étape suivante...\n";
    }
    
    // Mettre à jour les enregistrements existants
    echo "Migration des enregistrements existants...\n";
    
    $stmt = $pdo->prepare("
        UPDATE `commissions` 
        SET `source_shop_id` = `shop_id` 
        WHERE `shop_id` IS NOT NULL AND `source_shop_id` IS NULL
    ");
    $count = $stmt->execute();
    
    echo "$count enregistrements migrés.\n";
    
    // Créer les index pour les nouveaux patterns de recherche
    echo "Création des index pour les nouveaux patterns de recherche...\n";
    
    try {
        $pdo->exec("CREATE INDEX `idx_source_dest_commission` ON `commissions` (`source_shop_id`, `destination_shop_id`, `type`)");
        echo "Index idx_source_dest_commission créé.\n";
    } catch (Exception $e) {
        echo "Index idx_source_dest_commission existe déjà.\n";
    }
    
    try {
        $pdo->exec("CREATE INDEX `idx_source_commission` ON `commissions` (`source_shop_id`, `type`)");
        echo "Index idx_source_commission créé.\n";
    } catch (Exception $e) {
        echo "Index idx_source_commission existe déjà.\n";
    }
    
    // Commit de la transaction
    $pdo->commit();
    
    echo "\nMigration terminée avec succès!\n";
    echo "La table commissions a été mise à jour pour supporter les commissions par route (source -> destination).\n";
    echo "\nInstructions :\n";
    echo "1. Les API de synchronisation ont été mises à jour\n";
    echo "2. Vous pouvez maintenant créer des commissions spécifiques entre shops\n";
    echo "3. Exemple : (BUTEMBO - KAMPALA) : 1%, (BUTEMBO - KINDU) : 1.5%\n";
    
} catch (Exception $e) {
    // Rollback en cas d'erreur
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    echo "Erreur lors de la migration : " . $e->getMessage() . "\n";
    echo "La transaction a été annulée.\n";
    exit(1);
}
?>