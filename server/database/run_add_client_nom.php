<?php
// Script pour ajouter la colonne client_nom à la table operations
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../classes/Database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo "=== Migration: Ajouter client_nom à operations ===\n\n";
    
    // Vérifier si la colonne existe déjà
    $checkColumn = $db->query("
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'ucash_db' 
        AND TABLE_NAME = 'operations' 
        AND COLUMN_NAME = 'client_nom'
    ")->fetch();
    
    if ($checkColumn) {
        echo "✅ La colonne 'client_nom' existe déjà.\n";
    } else {
        echo "1. Ajout de la colonne 'client_nom'...\n";
        $db->exec("
            ALTER TABLE operations 
            ADD COLUMN client_nom VARCHAR(255) DEFAULT NULL AFTER client_id
        ");
        echo "   ✅ Colonne ajoutée\n\n";
        
        echo "2. Ajout de l'index idx_client_nom...\n";
        $db->exec("
            ALTER TABLE operations 
            ADD INDEX idx_client_nom (client_nom)
        ");
        echo "   ✅ Index ajouté\n\n";
    }
    
    // Mettre à jour les valeurs existantes
    echo "3. Mise à jour des noms de clients existants...\n";
    $updateStmt = $db->exec("
        UPDATE operations o
        INNER JOIN clients c ON o.client_id = c.id
        SET o.client_nom = c.nom
        WHERE o.client_id IS NOT NULL
    ");
    echo "   ✅ $updateStmt ligne(s) mise(s) à jour\n\n";
    
    // Vérifier le résultat
    echo "4. Vérification...\n";
    $result = $db->query("
        SELECT COUNT(*) as total_operations, 
               COUNT(client_nom) as operations_avec_nom,
               COUNT(client_id) as operations_avec_client_id
        FROM operations
    ")->fetch(PDO::FETCH_ASSOC);
    
    echo "   Total opérations: {$result['total_operations']}\n";
    echo "   Avec client_nom: {$result['operations_avec_nom']}\n";
    echo "   Avec client_id: {$result['operations_avec_client_id']}\n\n";
    
    // Afficher quelques exemples
    echo "5. Exemples d'opérations avec client_nom:\n";
    $examples = $db->query("
        SELECT id, client_id, client_nom, type, montant_brut, created_at 
        FROM operations 
        WHERE client_id IS NOT NULL 
        LIMIT 5
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($examples as $op) {
        echo "   - ID: {$op['id']}, Client: {$op['client_nom']}, Type: {$op['type']}, Montant: {$op['montant_brut']}\n";
    }
    
    echo "\n=== Migration terminée avec succès ===\n";
    
    // Retourner aussi en JSON pour l'interface web
    echo "\n" . json_encode([
        'success' => true,
        'message' => 'Migration réussie',
        'stats' => $result
    ]);
    
} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
    exit(1);
}
?>
