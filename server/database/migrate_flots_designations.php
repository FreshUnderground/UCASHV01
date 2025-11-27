<?php
/**
 * Script de migration: Ajouter shop_source_designation et shop_destination_designation à la table flots
 * 
 * Exécution: Naviguer vers ce script dans le navigateur ou exécuter via CLI
 */

header('Content-Type: text/html; charset=utf-8');

require_once '../../config/database.php';
require_once '../../classes/Database.php';

echo "<h2>Migration: Ajout des colonnes de désignation des shops dans la table flots</h2>";

try {
    $db = Database::getInstance();
    $pdo = $db->getConnection();
    
    echo "<p>🔄 Connexion à la base de données réussie</p>";
    
    // Vérifier si les colonnes existent déjà
    $checkStmt = $pdo->query("SHOW COLUMNS FROM flots LIKE 'shop_source_designation'");
    if ($checkStmt->rowCount() > 0) {
        echo "<p>⚠️ La colonne 'shop_source_designation' existe déjà. Migration ignorée.</p>";
        exit();
    }
    
    echo "<p>📋 Lecture du fichier de migration...</p>";
    $sqlFile = __DIR__ . '/migrations/add_shop_designations_to_flots.sql';
    $sql = file_get_contents($sqlFile);
    
    // Séparer les requêtes SQL
    $queries = array_filter(array_map('trim', explode(';', $sql)));
    
    echo "<p>🚀 Exécution de la migration...</p>";
    
    $pdo->beginTransaction();
    
    foreach ($queries as $query) {
        // Ignorer les commentaires et les lignes vides
        if (empty($query) || strpos($query, '--') === 0) {
            continue;
        }
        
        try {
            $pdo->exec($query);
            echo "<p>✅ Requête exécutée: " . substr($query, 0, 50) . "...</p>";
        } catch (PDOException $e) {
            echo "<p>⚠️ Avertissement: " . $e->getMessage() . "</p>";
        }
    }
    
    $pdo->commit();
    
    echo "<h3>✅ Migration terminée avec succès!</h3>";
    echo "<p>Les colonnes 'shop_source_designation' et 'shop_destination_designation' ont été ajoutées à la table 'flots'.</p>";
    echo "<p>Les données existantes ont été mises à jour avec les désignations des shops.</p>";
    
    // Vérifier les données
    $checkData = $pdo->query("SELECT COUNT(*) as total, 
                                     SUM(CASE WHEN shop_source_designation IS NOT NULL THEN 1 ELSE 0 END) as with_source,
                                     SUM(CASE WHEN shop_destination_designation IS NOT NULL THEN 1 ELSE 0 END) as with_dest
                              FROM flots");
    $stats = $checkData->fetch(PDO::FETCH_ASSOC);
    
    echo "<h4>Statistiques:</h4>";
    echo "<ul>";
    echo "<li>Total de flots: {$stats['total']}</li>";
    echo "<li>Avec shop_source_designation: {$stats['with_source']}</li>";
    echo "<li>Avec shop_destination_designation: {$stats['with_dest']}</li>";
    echo "</ul>";
    
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    
    echo "<h3>❌ Erreur lors de la migration</h3>";
    echo "<p style='color: red;'>" . $e->getMessage() . "</p>";
    echo "<pre>" . $e->getTraceAsString() . "</pre>";
}
?>
