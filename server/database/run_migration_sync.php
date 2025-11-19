<?php
/**
 * Script de migration automatique pour ajouter les colonnes de synchronisation
 * aux tables document_headers et cloture_caisse
 */

header('Content-Type: application/json; charset=utf-8');

try {
    require_once '../config/database.php';
    
    $results = [];
    
    // ========================================================================
    // MIGRATION: document_headers
    // ========================================================================
    
    echo "=== Migration document_headers ===\n";
    
    // Ajouter last_modified_at
    try {
        $pdo->exec("ALTER TABLE `document_headers` 
                    ADD COLUMN `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
                    COMMENT 'Dernière modification'");
        $results[] = "✅ Colonne last_modified_at ajoutée à document_headers";
        echo "✅ Colonne last_modified_at ajoutée\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate column') !== false) {
            $results[] = "⚠️ Colonne last_modified_at existe déjà";
            echo "⚠️ Colonne last_modified_at existe déjà\n";
        } else {
            throw $e;
        }
    }
    
    // Ajouter last_modified_by
    try {
        $pdo->exec("ALTER TABLE `document_headers` 
                    ADD COLUMN `last_modified_by` VARCHAR(100) DEFAULT 'system' 
                    COMMENT 'Modifié par (username)'");
        $results[] = "✅ Colonne last_modified_by ajoutée à document_headers";
        echo "✅ Colonne last_modified_by ajoutée\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate column') !== false) {
            $results[] = "⚠️ Colonne last_modified_by existe déjà";
            echo "⚠️ Colonne last_modified_by existe déjà\n";
        } else {
            throw $e;
        }
    }
    
    // Renommer is_modified en is_synced
    try {
        $pdo->exec("ALTER TABLE `document_headers` 
                    CHANGE COLUMN `is_modified` `is_synced` TINYINT(1) DEFAULT 0 
                    COMMENT 'Synchronisé avec le serveur'");
        $results[] = "✅ Colonne is_modified renommée en is_synced";
        echo "✅ Colonne is_modified renommée en is_synced\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), "Unknown column 'is_modified'") !== false) {
            // La colonne n'existe pas, vérifier si is_synced existe
            try {
                $pdo->exec("ALTER TABLE `document_headers` 
                            ADD COLUMN `is_synced` TINYINT(1) DEFAULT 0 
                            COMMENT 'Synchronisé avec le serveur'");
                $results[] = "✅ Colonne is_synced ajoutée à document_headers";
                echo "✅ Colonne is_synced ajoutée\n";
            } catch (PDOException $e2) {
                if (strpos($e2->getMessage(), 'Duplicate column') !== false) {
                    $results[] = "⚠️ Colonne is_synced existe déjà";
                    echo "⚠️ Colonne is_synced existe déjà\n";
                } else {
                    throw $e2;
                }
            }
        } else {
            throw $e;
        }
    }
    
    // Renommer last_synced_at en synced_at
    try {
        $pdo->exec("ALTER TABLE `document_headers` 
                    CHANGE COLUMN `last_synced_at` `synced_at` DATETIME DEFAULT NULL 
                    COMMENT 'Date de dernière synchronisation'");
        $results[] = "✅ Colonne last_synced_at renommée en synced_at";
        echo "✅ Colonne last_synced_at renommée en synced_at\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), "Unknown column 'last_synced_at'") !== false) {
            // La colonne n'existe pas, vérifier si synced_at existe
            try {
                $pdo->exec("ALTER TABLE `document_headers` 
                            ADD COLUMN `synced_at` DATETIME DEFAULT NULL 
                            COMMENT 'Date de dernière synchronisation'");
                $results[] = "✅ Colonne synced_at ajoutée à document_headers";
                echo "✅ Colonne synced_at ajoutée\n";
            } catch (PDOException $e2) {
                if (strpos($e2->getMessage(), 'Duplicate column') !== false) {
                    $results[] = "⚠️ Colonne synced_at existe déjà";
                    echo "⚠️ Colonne synced_at existe déjà\n";
                } else {
                    throw $e2;
                }
            }
        } else {
            throw $e;
        }
    }
    
    // Ajouter l'index
    try {
        $pdo->exec("ALTER TABLE `document_headers` 
                    ADD INDEX `idx_sync` (`is_synced`, `last_modified_at`)");
        $results[] = "✅ Index idx_sync ajouté à document_headers";
        echo "✅ Index idx_sync ajouté\n";
    } catch (PDOException $e) {
        if (strpos($e->getMessage(), 'Duplicate key') !== false) {
            $results[] = "⚠️ Index idx_sync existe déjà";
            echo "⚠️ Index idx_sync existe déjà\n";
        } else {
            throw $e;
        }
    }
    
    // ========================================================================
    // MIGRATION: cloture_caisse
    // ========================================================================
    
    echo "\n=== Migration cloture_caisse ===\n";
    
    // Vérifier si la table existe
    $stmt = $pdo->query("SHOW TABLES LIKE 'cloture_caisse'");
    $tableExists = $stmt->rowCount() > 0;
    
    if (!$tableExists) {
        // Créer la table complète
        $sql = "CREATE TABLE `cloture_caisse` (
          `id` INT(11) NOT NULL AUTO_INCREMENT,
          `shop_id` INT(11) NOT NULL COMMENT 'ID du shop',
          `date_cloture` DATE NOT NULL COMMENT 'Date de fin de journée',
          
          `solde_saisi_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_saisi_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_saisi_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_saisi_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_saisi_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          
          `solde_calcule_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_calcule_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_calcule_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_calcule_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `solde_calcule_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          
          `ecart_cash` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `ecart_airtel_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `ecart_mpesa` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `ecart_orange_money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          `ecart_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
          
          `cloture_par` VARCHAR(50) NOT NULL COMMENT 'Username de l\\'agent',
          `date_enregistrement` DATETIME NOT NULL COMMENT 'Date/heure d\\'enregistrement',
          `notes` TEXT DEFAULT NULL COMMENT 'Notes optionnelles',
          `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
          
          `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Dernière modification',
          `last_modified_by` VARCHAR(100) DEFAULT 'system' COMMENT 'Modifié par (username)',
          `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec le serveur',
          `synced_at` DATETIME DEFAULT NULL COMMENT 'Date de dernière synchronisation',
          
          PRIMARY KEY (`id`),
          UNIQUE KEY `unique_cloture_shop_date` (`shop_id`, `date_cloture`),
          INDEX `idx_shop_id` (`shop_id`),
          INDEX `idx_date_cloture` (`date_cloture`),
          INDEX `idx_sync` (`is_synced`, `last_modified_at`),
          CONSTRAINT `fk_cloture_shop` FOREIGN KEY (`shop_id`) REFERENCES `shops` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        COMMENT='Clôtures de caisse quotidiennes'";
        
        $pdo->exec($sql);
        $results[] = "✅ Table cloture_caisse créée avec succès";
        echo "✅ Table cloture_caisse créée avec succès\n";
    } else {
        // La table existe, ajouter les colonnes manquantes
        echo "⚠️ Table cloture_caisse existe déjà, ajout des colonnes de sync...\n";
        
        try {
            $pdo->exec("ALTER TABLE `cloture_caisse` 
                        ADD COLUMN `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
                        COMMENT 'Dernière modification'");
            $results[] = "✅ Colonne last_modified_at ajoutée à cloture_caisse";
            echo "✅ Colonne last_modified_at ajoutée\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate column') !== false) {
                $results[] = "⚠️ Colonne last_modified_at existe déjà";
                echo "⚠️ Colonne last_modified_at existe déjà\n";
            } else {
                throw $e;
            }
        }
        
        try {
            $pdo->exec("ALTER TABLE `cloture_caisse` 
                        ADD COLUMN `last_modified_by` VARCHAR(100) DEFAULT 'system' 
                        COMMENT 'Modifié par (username)'");
            $results[] = "✅ Colonne last_modified_by ajoutée à cloture_caisse";
            echo "✅ Colonne last_modified_by ajoutée\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate column') !== false) {
                $results[] = "⚠️ Colonne last_modified_by existe déjà";
                echo "⚠️ Colonne last_modified_by existe déjà\n";
            } else {
                throw $e;
            }
        }
        
        try {
            $pdo->exec("ALTER TABLE `cloture_caisse` 
                        ADD COLUMN `is_synced` TINYINT(1) DEFAULT 0 
                        COMMENT 'Synchronisé avec le serveur'");
            $results[] = "✅ Colonne is_synced ajoutée à cloture_caisse";
            echo "✅ Colonne is_synced ajoutée\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate column') !== false) {
                $results[] = "⚠️ Colonne is_synced existe déjà";
                echo "⚠️ Colonne is_synced existe déjà\n";
            } else {
                throw $e;
            }
        }
        
        try {
            $pdo->exec("ALTER TABLE `cloture_caisse` 
                        ADD COLUMN `synced_at` DATETIME DEFAULT NULL 
                        COMMENT 'Date de dernière synchronisation'");
            $results[] = "✅ Colonne synced_at ajoutée à cloture_caisse";
            echo "✅ Colonne synced_at ajoutée\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate column') !== false) {
                $results[] = "⚠️ Colonne synced_at existe déjà";
                echo "⚠️ Colonne synced_at existe déjà\n";
            } else {
                throw $e;
            }
        }
        
        try {
            $pdo->exec("ALTER TABLE `cloture_caisse` 
                        ADD INDEX `idx_sync` (`is_synced`, `last_modified_at`)");
            $results[] = "✅ Index idx_sync ajouté à cloture_caisse";
            echo "✅ Index idx_sync ajouté\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'Duplicate key') !== false) {
                $results[] = "⚠️ Index idx_sync existe déjà";
                echo "⚠️ Index idx_sync existe déjà\n";
            } else {
                throw $e;
            }
        }
    }
    
    // ========================================================================
    // RÉSUMÉ
    // ========================================================================
    
    echo "\n=== MIGRATION TERMINÉE ===\n";
    echo json_encode([
        'success' => true,
        'message' => 'Migration terminée avec succès',
        'results' => $results,
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo "\n=== ERREUR ===\n";
    echo json_encode([
        'success' => false,
        'message' => 'Erreur lors de la migration: ' . $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'timestamp' => date('c')
    ], JSON_PRETTY_PRINT);
    http_response_code(500);
}
?>
