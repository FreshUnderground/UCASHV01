<?php
/**
 * Script d'initialisation de la table RETRAIT_VIRTUELS
 * Crée la table si elle n'existe pas ou ajoute les colonnes manquantes
 */

require_once __DIR__ . '/config/database.php';

echo "========================================\n";
echo "INITIALISATION DE LA TABLE RETRAIT_VIRTUELS\n";
echo "========================================\n\n";

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // ========================================================================
    // VÉRIFICATION ET CRÉATION DE LA TABLE RETRAIT_VIRTUELS
    // ========================================================================
    
    echo "📱 Vérification de la table RETRAIT_VIRTUELS...\n";
    
    $createRetraitsTable = "
    CREATE TABLE IF NOT EXISTS retrait_virtuels (
        id INT PRIMARY KEY AUTO_INCREMENT,
        sim_numero VARCHAR(20) NOT NULL,
        sim_operateur VARCHAR(50),
        shop_source_id INT NOT NULL,
        shop_source_designation VARCHAR(255),
        shop_debiteur_id INT NOT NULL,
        shop_debiteur_designation VARCHAR(255),
        montant DECIMAL(15,2) NOT NULL,
        devise VARCHAR(10) DEFAULT 'USD',
        solde_avant DECIMAL(15,2) NOT NULL,
        solde_apres DECIMAL(15,2) NOT NULL,
        agent_id INT NOT NULL,
        agent_username VARCHAR(100),
        notes TEXT,
        statut ENUM('enAttente', 'rembourse', 'annule') DEFAULT 'enAttente',
        date_retrait DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        date_remboursement DATETIME,
        flot_remboursement_id INT,
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        INDEX idx_retrait_sim (sim_numero),
        INDEX idx_retrait_shop_source (shop_source_id),
        INDEX idx_retrait_shop_debiteur (shop_debiteur_id),
        INDEX idx_retrait_agent (agent_id),
        INDEX idx_retrait_statut (statut),
        INDEX idx_retrait_date (date_retrait),
        INDEX idx_retrait_sync (is_synced, last_modified_at),
        FOREIGN KEY (shop_source_id) REFERENCES shops(id) ON DELETE RESTRICT,
        FOREIGN KEY (shop_debiteur_id) REFERENCES shops(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ";
    
    $conn->exec($createRetraitsTable);
    echo "✅ Table RETRAIT_VIRTUELS vérifiée/créée\n";
    
    // Vérifier et ajouter les colonnes manquantes si nécessaire
    $checkColumns = $conn->query("SHOW COLUMNS FROM retrait_virtuels");
    $columns = $checkColumns->fetchAll(PDO::FETCH_COLUMN);
    
    $requiredColumns = [
        'devise' => "ALTER TABLE retrait_virtuels ADD COLUMN devise VARCHAR(10) DEFAULT 'USD' AFTER montant",
        'last_modified_at' => "ALTER TABLE retrait_virtuels ADD COLUMN last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER flot_remboursement_id",
        'last_modified_by' => "ALTER TABLE retrait_virtuels ADD COLUMN last_modified_by VARCHAR(100) AFTER last_modified_at",
        'is_synced' => "ALTER TABLE retrait_virtuels ADD COLUMN is_synced TINYINT(1) DEFAULT 0 AFTER last_modified_by",
        'synced_at' => "ALTER TABLE retrait_virtuels ADD COLUMN synced_at DATETIME AFTER is_synced"
    ];
    
    foreach ($requiredColumns as $colName => $alterSql) {
        if (!in_array($colName, $columns)) {
            try {
                $conn->exec($alterSql);
                echo "   ✅ Colonne '$colName' ajoutée à RETRAIT_VIRTUELS\n";
            } catch (PDOException $e) {
                echo "   ⚠️ Colonne '$colName': " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Compter les retraits virtuels
    $countStmt = $conn->query("SELECT COUNT(*) FROM retrait_virtuels");
    $retraitCount = $countStmt->fetchColumn();
    echo "   📊 Nombre de retraits virtuels: $retraitCount\n\n";
    
    // ========================================================================
    // VÉRIFICATION DES INDEX
    // ========================================================================
    
    echo "🔍 Vérification des index...\n";
    
    $indexes = [
        'idx_retrait_sim' => "CREATE INDEX idx_retrait_sim ON retrait_virtuels (sim_numero)",
        'idx_retrait_shop_source' => "CREATE INDEX idx_retrait_shop_source ON retrait_virtuels (shop_source_id)",
        'idx_retrait_shop_debiteur' => "CREATE INDEX idx_retrait_shop_debiteur ON retrait_virtuels (shop_debiteur_id)",
        'idx_retrait_agent' => "CREATE INDEX idx_retrait_agent ON retrait_virtuels (agent_id)",
        'idx_retrait_statut' => "CREATE INDEX idx_retrait_statut ON retrait_virtuels (statut)",
        'idx_retrait_date' => "CREATE INDEX idx_retrait_date ON retrait_virtuels (date_retrait)",
        'idx_retrait_sync' => "CREATE INDEX idx_retrait_sync ON retrait_virtuels (is_synced, last_modified_at)"
    ];
    
    // Récupérer les index existants
    $existingIndexes = $conn->query("SHOW INDEX FROM retrait_virtuels")->fetchAll(PDO::FETCH_COLUMN, 2);
    
    foreach ($indexes as $indexName => $createSql) {
        if (!in_array($indexName, $existingIndexes)) {
            try {
                $conn->exec($createSql);
                echo "   ✅ Index '$indexName' créé\n";
            } catch (PDOException $e) {
                echo "   ⚠️ Index '$indexName': " . $e->getMessage() . "\n";
            }
        } else {
            echo "   ℹ️ Index '$indexName' existe déjà\n";
        }
    }
    
    echo "\n========================================\n";
    echo "✅ INITIALISATION RETRAIT_VIRTUELS TERMINÉE AVEC SUCCÈS\n";
    echo "========================================\n";
    
} catch (PDOException $e) {
    echo "❌ Erreur de base de données: " . $e->getMessage() . "\n";
    echo "   Code: " . $e->getCode() . "\n";
    exit(1);
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    exit(1);
}
?>
