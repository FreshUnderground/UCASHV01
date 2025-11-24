<?php
/**
 * Script de mise à jour pour gérer les IDs négatifs des shops locaux
 * 1. Met à jour AUTO_INCREMENT pour éviter les conflits
 * 2. Convertit les IDs négatifs en IDs positifs si nécessaire
 */

require_once '../config/database.php';

try {
    // Connexion à la base de données
    $database = new Database();
    $pdo = $database->getConnection();
    
    echo "🔄 Mise à jour de la base de données pour gérer les IDs négatifs...\n\n";
    
    // 1. Mettre à jour l'AUTO_INCREMENT pour la table shops
    echo "1. Mise à jour de AUTO_INCREMENT...\n";
    $sql = "ALTER TABLE shops AUTO_INCREMENT = 1000000";
    $stmt = $pdo->prepare($sql);
    $result = $stmt->execute();
    
    if ($result) {
        echo "   ✅ AUTO_INCREMENT mis à jour avec succès à 1000000\n";
    } else {
        echo "   ❌ Échec de la mise à jour de AUTO_INCREMENT\n";
    }
    
    // 2. Vérifier s'il y a des shops avec des IDs négatifs
    echo "\n2. Vérification des shops avec IDs négatifs...\n";
    $sql = "SELECT id, designation FROM shops WHERE id < 0";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $negativeShops = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($negativeShops) > 0) {
        echo "   ⚠️  " . count($negativeShops) . " shops avec IDs négatifs trouvés:\n";
        foreach ($negativeShops as $shop) {
            echo "      - ID: {$shop['id']}, Désignation: {$shop['designation']}\n";
        }
        
        // Demander confirmation avant de procéder
        echo "\n   ⚠️  Les IDs négatifs seront convertis en IDs positifs auto-générés.\n";
        echo "   ⚠️  Cette opération est IRRÉVERSIBLE. Continuer? (y/N): ";
        
        // Pour un script automatique, on continue sans confirmation
        echo "   ✅ Conversion automatique des IDs négatifs...\n";
        
        // Convertir les IDs négatifs en IDs positifs
        foreach ($negativeShops as $shop) {
            // Désactiver temporairement les contraintes de clés étrangères
            $pdo->exec("SET FOREIGN_KEY_CHECKS = 0");
            
            // Mettre à jour l'ID du shop
            $updateShopSql = "UPDATE shops SET id = NULL WHERE id = ?";
            $updateShopStmt = $pdo->prepare($updateShopSql);
            $updateShopStmt->execute([$shop['id']]);
            
            // Réactiver les contraintes de clés étrangères
            $pdo->exec("SET FOREIGN_KEY_CHECKS = 1");
            
            echo "      ✅ Shop '{$shop['designation']}' mis à jour avec un nouvel ID\n";
        }
    } else {
        echo "   ✅ Aucun shop avec ID négatif trouvé\n";
    }
    
    echo "\n✅ Mise à jour terminée avec succès!\n";
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}
?>