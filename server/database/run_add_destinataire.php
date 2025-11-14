<?php
// Script pour ajouter les colonnes destinataire et telephone_destinataire
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: text/plain; charset=utf-8');

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../classes/Database.php';

try {
    $db = Database::getInstance()->getConnection();
    
    echo "=== Migration: Ajouter destinataire et client_nom aux opérations ===\n\n";
    
    // Vérifier si la colonne destinataire existe déjà
    $checkDestColumn = $db->query("
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'ucash_db' 
        AND TABLE_NAME = 'operations' 
        AND COLUMN_NAME = 'destinataire'
    ")->fetch();
    
    if ($checkDestColumn) {
        echo "✅ La colonne 'destinataire' existe déjà.\n";
    } else {
        echo "1. Ajout de la colonne 'destinataire'...\n";
        $db->exec("
            ALTER TABLE operations 
            ADD COLUMN destinataire VARCHAR(100) DEFAULT NULL AFTER notes
        ");
        echo "   ✅ Colonne 'destinataire' ajoutée\n\n";
    }
    
    // Vérifier si la colonne telephone_destinataire existe déjà
    $checkTelColumn = $db->query("
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'ucash_db' 
        AND TABLE_NAME = 'operations' 
        AND COLUMN_NAME = 'telephone_destinataire'
    ")->fetch();
    
    if ($checkTelColumn) {
        echo "✅ La colonne 'telephone_destinataire' existe déjà.\n";
    } else {
        echo "2. Ajout de la colonne 'telephone_destinataire'...\n";
        $db->exec("
            ALTER TABLE operations 
            ADD COLUMN telephone_destinataire VARCHAR(20) DEFAULT NULL AFTER destinataire
        ");
        echo "   ✅ Colonne 'telephone_destinataire' ajoutée\n\n";
    }
    
    // Vérifier si la colonne client_nom existe déjà
    $checkClientNomColumn = $db->query("
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = 'ucash_db' 
        AND TABLE_NAME = 'operations' 
        AND COLUMN_NAME = 'client_nom'
    ")->fetch();
    
    if ($checkClientNomColumn) {
        echo "✅ La colonne 'client_nom' existe déjà.\n\n";
    } else {
        echo "3. Ajout de la colonne 'client_nom'...\n";
        $db->exec("
            ALTER TABLE operations 
            ADD COLUMN client_nom VARCHAR(255) DEFAULT NULL AFTER client_id
        ");
        echo "   ✅ Colonne 'client_nom' ajoutée\n\n";
    }
    
    // Ajouter l'index idx_destinataire
    echo "4. Ajout de l'index idx_destinataire...\n";
    try {
        $db->exec("
            ALTER TABLE operations 
            ADD INDEX idx_destinataire (destinataire)
        ");
        echo "   ✅ Index idx_destinataire ajouté\n\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate key name') !== false) {
            echo "   ℹ️ Index idx_destinataire existe déjà\n\n";
        } else {
            throw $e;
        }
    }
    
    // Ajouter l'index idx_client_nom
    echo "5. Ajout de l'index idx_client_nom...\n";
    try {
        $db->exec("
            ALTER TABLE operations 
            ADD INDEX idx_client_nom (client_nom)
        ");
        echo "   ✅ Index idx_client_nom ajouté\n\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate key name') !== false) {
            echo "   ℹ️ Index idx_client_nom existe déjà\n\n";
        } else {
            throw $e;
        }
    }
    
    // Remplir les noms de clients existants
    echo "6. Remplissage des noms de clients existants...\n";
    $updateCount = $db->exec("
        UPDATE operations o
        INNER JOIN clients c ON o.client_id = c.id
        SET o.client_nom = c.nom
        WHERE o.client_id IS NOT NULL AND o.client_nom IS NULL
    ");
    echo "   ✅ {$updateCount} client_nom mis à jour\n\n";
    
    // Vérifier le résultat
    echo "7. Vérification...\n";
    $result = $db->query("
        SELECT COUNT(*) as total_operations,
               COUNT(destinataire) as operations_avec_destinataire,
               COUNT(client_nom) as operations_avec_client_nom
        FROM operations
    ")->fetch(PDO::FETCH_ASSOC);
    
    echo "   Total opérations: {$result['total_operations']}\n";
    echo "   Avec destinataire: {$result['operations_avec_destinataire']}\n";
    echo "   Avec client_nom: {$result['operations_avec_client_nom']}\n\n";
    
    // Afficher quelques exemples
    echo "8. Exemples d'opérations:\n";
    $examples = $db->query("
        SELECT id, type, client_nom, destinataire, telephone_destinataire, montant_brut, created_at 
        FROM operations 
        LIMIT 5
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($examples) > 0) {
        foreach ($examples as $op) {
            $clientNom = $op['client_nom'] ?? 'NULL';
            $dest = $op['destinataire'] ?? 'NULL';
            $tel = $op['telephone_destinataire'] ?? 'NULL';
            echo "   - ID: {$op['id']}, Type: {$op['type']}, Client: {$clientNom}, Destinataire: {$dest}, Tel: {$tel}, Montant: {$op['montant_brut']}\n";
        }
    } else {
        echo "   Aucune opération trouvée\n";
    }
    
    echo "\n=== ✅ Migration terminée avec succès ===\n";
    
} catch (Exception $e) {
    echo "❌ ERREUR: " . $e->getMessage() . "\n";
    echo "Fichier: " . $e->getFile() . "\n";
    echo "Ligne: " . $e->getLine() . "\n";
    exit(1);
}
?>
