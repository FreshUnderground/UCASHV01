<?php
/**
 * Script d'initialisation de la table CREDIT_VIRTUELS
 * Crée la table si elle n'existe pas ou ajoute les colonnes manquantes
 */

require_once __DIR__ . '/config/database.php';

echo "========================================\n";
echo "INITIALISATION DE LA TABLE CREDIT_VIRTUELS\n";
echo "========================================\n\n";

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // ========================================================================
    // VÉRIFICATION ET CRÉATION DE LA TABLE CREDIT_VIRTUELS
    // ========================================================================
    
    echo "💳 Vérification de la table CREDIT_VIRTUELS...\n";
    
    $createCreditsTable = "
    CREATE TABLE IF NOT EXISTS credit_virtuels (
        id INT PRIMARY KEY AUTO_INCREMENT,
        reference VARCHAR(50) NOT NULL UNIQUE,
        montant_credit DECIMAL(15,2) NOT NULL,
        devise VARCHAR(10) DEFAULT 'USD',
        beneficiaire_nom VARCHAR(255) NOT NULL,
        beneficiaire_telephone VARCHAR(20),
        beneficiaire_adresse TEXT,
        type_beneficiaire ENUM('shop', 'partenaire', 'autre') DEFAULT 'shop',
        sim_numero VARCHAR(20) NOT NULL,
        shop_id INT NOT NULL,
        shop_designation VARCHAR(255),
        agent_id INT NOT NULL,
        agent_username VARCHAR(100),
        statut ENUM('accorde', 'partiellementPaye', 'paye', 'annule', 'enRetard') DEFAULT 'accorde',
        date_sortie DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        date_paiement DATETIME,
        date_echeance DATETIME,
        notes TEXT,
        montant_paye DECIMAL(15,2) DEFAULT 0.00,
        mode_paiement VARCHAR(50),
        reference_paiement VARCHAR(100),
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        INDEX idx_credit_reference (reference),
        INDEX idx_credit_shop (shop_id),
        INDEX idx_credit_sim (sim_numero),
        INDEX idx_credit_agent (agent_id),
        INDEX idx_credit_statut (statut),
        INDEX idx_credit_date (date_sortie),
        INDEX idx_credit_sync (is_synced, last_modified_at),
        INDEX idx_credit_beneficiaire (beneficiaire_nom),
        FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ";
    
    $conn->exec($createCreditsTable);
    echo "✅ Table CREDIT_VIRTUELS vérifiée/créée\n";
    
    // Vérifier et ajouter les colonnes manquantes si nécessaire
    $checkColumns = $conn->query("SHOW COLUMNS FROM credit_virtuels");
    $columns = $checkColumns->fetchAll(PDO::FETCH_COLUMN);
    
    $requiredColumns = [
        'devise' => "ALTER TABLE credit_virtuels ADD COLUMN devise VARCHAR(10) DEFAULT 'USD' AFTER montant_credit",
        'beneficiaire_telephone' => "ALTER TABLE credit_virtuels ADD COLUMN beneficiaire_telephone VARCHAR(20) AFTER beneficiaire_nom",
        'beneficiaire_adresse' => "ALTER TABLE credit_virtuels ADD COLUMN beneficiaire_adresse TEXT AFTER beneficiaire_telephone",
        'type_beneficiaire' => "ALTER TABLE credit_virtuels ADD COLUMN type_beneficiaire ENUM('shop', 'partenaire', 'autre') DEFAULT 'shop' AFTER beneficiaire_adresse",
        'date_echeance' => "ALTER TABLE credit_virtuels ADD COLUMN date_echeance DATETIME AFTER date_paiement",
        'montant_paye' => "ALTER TABLE credit_virtuels ADD COLUMN montant_paye DECIMAL(15,2) DEFAULT 0.00 AFTER notes",
        'mode_paiement' => "ALTER TABLE credit_virtuels ADD COLUMN mode_paiement VARCHAR(50) AFTER montant_paye",
        'reference_paiement' => "ALTER TABLE credit_virtuels ADD COLUMN reference_paiement VARCHAR(100) AFTER mode_paiement",
        'last_modified_at' => "ALTER TABLE credit_virtuels ADD COLUMN last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER reference_paiement",
        'last_modified_by' => "ALTER TABLE credit_virtuels ADD COLUMN last_modified_by VARCHAR(100) AFTER last_modified_at",
        'is_synced' => "ALTER TABLE credit_virtuels ADD COLUMN is_synced TINYINT(1) DEFAULT 0 AFTER last_modified_by",
        'synced_at' => "ALTER TABLE credit_virtuels ADD COLUMN synced_at DATETIME AFTER is_synced"
    ];
    
    foreach ($requiredColumns as $colName => $alterSql) {
        if (!in_array($colName, $columns)) {
            try {
                $conn->exec($alterSql);
                echo "   ✅ Colonne '$colName' ajoutée à CREDIT_VIRTUELS\n";
            } catch (PDOException $e) {
                echo "   ⚠️ Colonne '$colName': " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Compter les crédits virtuels
    $countStmt = $conn->query("SELECT COUNT(*) FROM credit_virtuels");
    $creditCount = $countStmt->fetchColumn();
    echo "   📊 Nombre de crédits virtuels: $creditCount\n\n";
    
    // ========================================================================
    // VÉRIFICATION DES INDEX
    // ========================================================================
    
    echo "🔍 Vérification des index...\n";
    
    $indexes = [
        'idx_credit_reference' => "CREATE INDEX idx_credit_reference ON credit_virtuels (reference)",
        'idx_credit_shop' => "CREATE INDEX idx_credit_shop ON credit_virtuels (shop_id)",
        'idx_credit_sim' => "CREATE INDEX idx_credit_sim ON credit_virtuels (sim_numero)",
        'idx_credit_agent' => "CREATE INDEX idx_credit_agent ON credit_virtuels (agent_id)",
        'idx_credit_statut' => "CREATE INDEX idx_credit_statut ON credit_virtuels (statut)",
        'idx_credit_date' => "CREATE INDEX idx_credit_date ON credit_virtuels (date_sortie)",
        'idx_credit_sync' => "CREATE INDEX idx_credit_sync ON credit_virtuels (is_synced, last_modified_at)",
        'idx_credit_beneficiaire' => "CREATE INDEX idx_credit_beneficiaire ON credit_virtuels (beneficiaire_nom)"
    ];
    
    // Récupérer les index existants
    $existingIndexes = $conn->query("SHOW INDEX FROM credit_virtuels")->fetchAll(PDO::FETCH_COLUMN, 2);
    
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
    
    // ========================================================================
    // VÉRIFICATION DE LA CONTRAINTE UNIQUE SUR REFERENCE
    // ========================================================================
    
    echo "\n🔒 Vérification contrainte unique sur référence...\n";
    
    try {
        $conn->exec("ALTER TABLE credit_virtuels ADD CONSTRAINT uk_credit_reference UNIQUE (reference)");
        echo "   ✅ Contrainte unique sur référence ajoutée\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate key name') !== false) {
            echo "   ℹ️ Contrainte unique sur référence existe déjà\n";
        } else {
            echo "   ⚠️ Contrainte unique: " . $e->getMessage() . "\n";
        }
    }
    
    echo "\n========================================\n";
    echo "✅ INITIALISATION CREDIT_VIRTUELS TERMINÉE AVEC SUCCÈS\n";
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
