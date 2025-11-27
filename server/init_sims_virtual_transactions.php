<?php
/**
 * Script d'initialisation des tables SIMS et VIRTUAL_TRANSACTIONS
 * Crée les tables si elles n'existent pas ou ajoute les colonnes manquantes
 */

require_once __DIR__ . '/config/database.php';

echo "========================================\n";
echo "INITIALISATION DES TABLES SIMS ET VIRTUAL_TRANSACTIONS\n";
echo "========================================\n\n";

try {
    $db = new Database();
    $conn = $db->getConnection();
    
    // ========================================================================
    // VÉRIFICATION ET CRÉATION DE LA TABLE SIMS
    // ========================================================================
    
    echo "📱 Vérification de la table SIMS...\n";
    
    $createSimsTable = "
    CREATE TABLE IF NOT EXISTS sims (
        id INT PRIMARY KEY AUTO_INCREMENT,
        numero VARCHAR(20) NOT NULL UNIQUE,
        operateur VARCHAR(50) NOT NULL,
        shop_id INT NOT NULL,
        shop_designation VARCHAR(255),
        solde_initial DECIMAL(15,2) DEFAULT 0.00,
        solde_actuel DECIMAL(15,2) DEFAULT 0.00,
        statut ENUM('active', 'suspendue', 'perdue', 'desactivee') DEFAULT 'active',
        motif_suspension TEXT,
        date_creation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        date_suspension DATETIME,
        cree_par VARCHAR(100),
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        INDEX idx_sim_numero (numero),
        INDEX idx_sim_shop (shop_id),
        INDEX idx_sim_operateur (operateur),
        INDEX idx_sim_statut (statut),
        INDEX idx_sim_sync (is_synced, last_modified_at),
        FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ";
    
    $conn->exec($createSimsTable);
    echo "✅ Table SIMS vérifiée/créée\n";
    
    // Vérifier et ajouter les colonnes manquantes si nécessaire
    $checkColumns = $conn->query("SHOW COLUMNS FROM sims");
    $columns = $checkColumns->fetchAll(PDO::FETCH_COLUMN);
    
    $requiredColumns = [
        'last_modified_at' => "ALTER TABLE sims ADD COLUMN last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER cree_par",
        'last_modified_by' => "ALTER TABLE sims ADD COLUMN last_modified_by VARCHAR(100) AFTER last_modified_at",
        'is_synced' => "ALTER TABLE sims ADD COLUMN is_synced TINYINT(1) DEFAULT 0 AFTER last_modified_by",
        'synced_at' => "ALTER TABLE sims ADD COLUMN synced_at DATETIME AFTER is_synced"
    ];
    
    foreach ($requiredColumns as $colName => $alterSql) {
        if (!in_array($colName, $columns)) {
            try {
                $conn->exec($alterSql);
                echo "   ✅ Colonne '$colName' ajoutée à SIMS\n";
            } catch (PDOException $e) {
                echo "   ⚠️ Colonne '$colName': " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Compter les SIMs
    $countStmt = $conn->query("SELECT COUNT(*) FROM sims");
    $simCount = $countStmt->fetchColumn();
    echo "   📊 Nombre de SIMs: $simCount\n\n";
    
    // ========================================================================
    // VÉRIFICATION ET CRÉATION DE LA TABLE VIRTUAL_TRANSACTIONS
    // ========================================================================
    
    echo "💰 Vérification de la table VIRTUAL_TRANSACTIONS...\n";
    
    $createVirtualTransactionsTable = "
    CREATE TABLE IF NOT EXISTS virtual_transactions (
        id INT PRIMARY KEY AUTO_INCREMENT,
        reference VARCHAR(100) NOT NULL UNIQUE,
        montant_virtuel DECIMAL(15,2) NOT NULL,
        frais DECIMAL(15,2) DEFAULT 0.00,
        montant_cash DECIMAL(15,2) NOT NULL,
        devise VARCHAR(10) DEFAULT 'USD',
        sim_numero VARCHAR(20) NOT NULL,
        shop_id INT NOT NULL,
        shop_designation VARCHAR(255),
        agent_id INT NOT NULL,
        agent_username VARCHAR(100),
        client_nom VARCHAR(255),
        client_telephone VARCHAR(20),
        statut ENUM('enAttente', 'validee', 'annulee') DEFAULT 'enAttente',
        date_enregistrement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        date_validation DATETIME,
        notes TEXT,
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        INDEX idx_vt_reference (reference),
        INDEX idx_vt_sim (sim_numero),
        INDEX idx_vt_shop (shop_id),
        INDEX idx_vt_agent (agent_id),
        INDEX idx_vt_statut (statut),
        INDEX idx_vt_date_enregistrement (date_enregistrement),
        INDEX idx_vt_date_validation (date_validation),
        INDEX idx_vt_sync (is_synced, last_modified_at),
        FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ";
    
    $conn->exec($createVirtualTransactionsTable);
    echo "✅ Table VIRTUAL_TRANSACTIONS vérifiée/créée\n";
    
    // Vérifier et ajouter les colonnes manquantes si nécessaire
    $checkVtColumns = $conn->query("SHOW COLUMNS FROM virtual_transactions");
    $vtColumns = $checkVtColumns->fetchAll(PDO::FETCH_COLUMN);
    
    $requiredVtColumns = [
        'last_modified_at' => "ALTER TABLE virtual_transactions ADD COLUMN last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER notes",
        'last_modified_by' => "ALTER TABLE virtual_transactions ADD COLUMN last_modified_by VARCHAR(100) AFTER last_modified_at",
        'is_synced' => "ALTER TABLE virtual_transactions ADD COLUMN is_synced TINYINT(1) DEFAULT 0 AFTER last_modified_by",
        'synced_at' => "ALTER TABLE virtual_transactions ADD COLUMN synced_at DATETIME AFTER is_synced"
    ];
    
    foreach ($requiredVtColumns as $colName => $alterSql) {
        if (!in_array($colName, $vtColumns)) {
            try {
                $conn->exec($alterSql);
                echo "   ✅ Colonne '$colName' ajoutée à VIRTUAL_TRANSACTIONS\n";
            } catch (PDOException $e) {
                echo "   ⚠️ Colonne '$colName': " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Compter les transactions virtuelles
    $countVtStmt = $conn->query("SELECT COUNT(*) FROM virtual_transactions");
    $vtCount = $countVtStmt->fetchColumn();
    echo "   📊 Nombre de transactions virtuelles: $vtCount\n\n";
    
    // ========================================================================
    // VÉRIFICATION DE LA TABLE SIM_MOVEMENTS
    // ========================================================================
    
    echo "📜 Vérification de la table SIM_MOVEMENTS...\n";
    
    $createSimMovementsTable = "
    CREATE TABLE IF NOT EXISTS sim_movements (
        id INT PRIMARY KEY AUTO_INCREMENT,
        sim_id INT NOT NULL,
        sim_numero VARCHAR(20) NOT NULL,
        ancien_shop_id INT,
        ancien_shop_designation VARCHAR(255),
        nouveau_shop_id INT NOT NULL,
        nouveau_shop_designation VARCHAR(255) NOT NULL,
        admin_responsable VARCHAR(100) NOT NULL,
        motif TEXT,
        date_movement DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_modified_by VARCHAR(100),
        is_synced TINYINT(1) DEFAULT 0,
        synced_at DATETIME,
        INDEX idx_movement_sim (sim_id),
        INDEX idx_movement_date (date_movement),
        INDEX idx_movement_shops (ancien_shop_id, nouveau_shop_id),
        INDEX idx_movement_sync (is_synced, last_modified_at),
        FOREIGN KEY (sim_id) REFERENCES sims(id) ON DELETE CASCADE,
        FOREIGN KEY (nouveau_shop_id) REFERENCES shops(id) ON DELETE RESTRICT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ";
    
    $conn->exec($createSimMovementsTable);
    echo "✅ Table SIM_MOVEMENTS vérifiée/créée\n";
    
    // Compter les mouvements
    $countMovStmt = $conn->query("SELECT COUNT(*) FROM sim_movements");
    $movCount = $countMovStmt->fetchColumn();
    echo "   📊 Nombre de mouvements: $movCount\n\n";
    
    echo "========================================\n";
    echo "✅ INITIALISATION TERMINÉE AVEC SUCCÈS\n";
    echo "========================================\n";
    
} catch (PDOException $e) {
    echo "❌ Erreur de base de données: " . $e->getMessage() . "\n";
    echo "   Code: " . $e->getCode() . "\n";
    exit(1);
} catch (Exception $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    exit(1);
}
