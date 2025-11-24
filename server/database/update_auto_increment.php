<?php
/**
 * Script de mise à jour pour AUTO_INCREMENT des shops
 * Permet d'éviter les conflits avec les IDs négatifs utilisés pour les shops locaux
 */

require_once '../config/database.php';

try {
    // Connexion à la base de données
    $database = new Database();
    $pdo = $database->getConnection();
    
    // Mettre à jour l'AUTO_INCREMENT pour la table shops
    $sql = "ALTER TABLE shops AUTO_INCREMENT = 1000000";
    $stmt = $pdo->prepare($sql);
    $result = $stmt->execute();
    
    if ($result) {
        echo "✅ AUTO_INCREMENT mis à jour avec succès à 1000000\n";
    } else {
        echo "❌ Échec de la mise à jour de AUTO_INCREMENT\n";
    }
    
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
}
?>