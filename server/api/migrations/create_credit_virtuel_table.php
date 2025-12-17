<?php
/**
 * Migration: Créer la table credit_virtuel
 * Description: Table pour la gestion des crédits virtuels entre shops/partenaires
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../../classes/Database.php';
require_once __DIR__ . '/../../config/database.php';

try {
    $database = Database::getInstance();
    $pdo = $database->getConnection();
    
    echo "🔄 Début de la migration: création de la table credit_virtuel...\n\n";
    
    // 1. Créer la table credit_virtuel
    $createTableSQL = "CREATE TABLE IF NOT EXISTS credit_virtuel (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reference VARCHAR(50) NOT NULL UNIQUE,
        montant_credit DECIMAL(15,2) NOT NULL,
        devise VARCHAR(3) NOT NULL DEFAULT 'USD',
        
        -- Informations bénéficiaire
        beneficiaire_nom VARCHAR(255) NOT NULL,
        beneficiaire_telephone VARCHAR(20),
        beneficiaire_adresse TEXT,
        type_beneficiaire ENUM('shop', 'partenaire', 'autre') NOT NULL DEFAULT 'shop',
        
        -- Informations SIM et shop émetteur
        sim_numero VARCHAR(20) NOT NULL,
        shop_id INT NOT NULL,
        shop_designation VARCHAR(255),
        
        -- Informations agent
        agent_id INT NOT NULL,
        agent_username VARCHAR(100),
        
        -- Statut du crédit
        statut ENUM('accorde', 'partiellement_paye', 'paye', 'annule', 'en_retard') NOT NULL DEFAULT 'accorde',
        
        -- Dates et tracking
        date_sortie DATETIME NOT NULL,
        date_paiement DATETIME NULL,
        date_echeance DATETIME NULL,
        notes TEXT,
        
        -- Informations de paiement
        montant_paye DECIMAL(15,2) DEFAULT 0.00,
        mode_paiement ENUM('cash', 'mobile_money', 'virement') NULL,
        reference_paiement VARCHAR(100) NULL,
        
        -- Synchronization
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced BOOLEAN DEFAULT FALSE,
        synced_at DATETIME NULL,
        
        -- Index pour optimiser les requêtes
        INDEX idx_reference (reference),
        INDEX idx_shop_id (shop_id),
        INDEX idx_sim_numero (sim_numero),
        INDEX idx_statut (statut),
        INDEX idx_date_sortie (date_sortie),
        INDEX idx_date_echeance (date_echeance),
        INDEX idx_beneficiaire (beneficiaire_nom),
        INDEX idx_sync (is_synced, last_modified_at)
    )";
    
    $pdo->exec($createTableSQL);
    echo "✅ Table credit_virtuel créée avec succès\n\n";
    
    // 2. Vérifier si la table existe
    $checkTable = $pdo->query("SHOW TABLES LIKE 'credit_virtuel'");
    if ($checkTable->rowCount() > 0) {
        echo "✅ Vérification: Table credit_virtuel existe\n\n";
        
        // Afficher la structure de la table
        $columns = $pdo->query("DESCRIBE credit_virtuel")->fetchAll(PDO::FETCH_ASSOC);
        echo "📋 Structure de la table:\n";
        foreach ($columns as $column) {
            echo "   - {$column['Field']} ({$column['Type']})\n";
        }
    } else {
        throw new Exception("La table credit_virtuel n'a pas été créée");
    }
    
    // 3. Créer le trigger pour la mise à jour automatique du statut
    echo "\n🔄 Création du trigger update_credit_status_after_payment...\n";
    
    // Supprimer le trigger s'il existe déjà
    $pdo->exec("DROP TRIGGER IF EXISTS update_credit_status_after_payment");
    
    $triggerSQL = "CREATE TRIGGER update_credit_status_after_payment
        BEFORE UPDATE ON credit_virtuel
        FOR EACH ROW
    BEGIN
        -- Mettre à jour le statut en fonction du montant payé
        IF NEW.montant_paye >= NEW.montant_credit THEN
            SET NEW.statut = 'paye';
            IF NEW.date_paiement IS NULL THEN
                SET NEW.date_paiement = NOW();
            END IF;
        ELSEIF NEW.montant_paye > 0 THEN
            SET NEW.statut = 'partiellement_paye';
        END IF;
        
        -- Vérifier si le crédit est en retard
        IF NEW.date_echeance IS NOT NULL 
           AND NOW() > NEW.date_echeance 
           AND NEW.statut NOT IN ('paye', 'annule') THEN
            SET NEW.statut = 'en_retard';
        END IF;
    END";
    
    $pdo->exec($triggerSQL);
    echo "✅ Trigger créé avec succès\n\n";
    
    // 4. Résumé final
    echo "🎉 Migration terminée avec succès!\n\n";
    echo json_encode([
        'success' => true,
        'message' => 'Table credit_virtuel créée avec succès',
        'table' => 'credit_virtuel',
        'columns' => count($columns),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo "\n❌ Erreur lors de la migration:\n";
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
}
?>
