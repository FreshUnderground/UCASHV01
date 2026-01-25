<?php
/**
 * Script pour initialiser la table document_headers sur le serveur
 * À exécuter une seule fois après déploiement
 */

require_once __DIR__ . '/config/database.php';

echo "🚀 Initialisation de la table document_headers...\n\n";

try {
    // Créer la table si elle n'existe pas
    echo "1. Création de la table document_headers...\n";
    $sql = "CREATE TABLE IF NOT EXISTS `document_headers` (
      `id` INT AUTO_INCREMENT PRIMARY KEY,
      `company_name` VARCHAR(255) NOT NULL COMMENT 'Nom de l''entreprise',
      `company_slogan` VARCHAR(500) NULL COMMENT 'Slogan ou devise de l''entreprise',
      `address` TEXT NULL COMMENT 'Adresse complète',
      `phone` VARCHAR(50) NULL COMMENT 'Numéro de téléphone',
      `email` VARCHAR(100) NULL COMMENT 'Adresse email',
      `website` VARCHAR(200) NULL COMMENT 'Site web',
      `logo_path` VARCHAR(500) NULL COMMENT 'Chemin vers le logo de l''entreprise',
      `tax_number` VARCHAR(100) NULL COMMENT 'Numéro fiscal / TVA',
      `registration_number` VARCHAR(100) NULL COMMENT 'Numéro d''enregistrement commercial',
      `is_active` TINYINT(1) DEFAULT 1 COMMENT 'En-tête actif (1) ou inactif (0)',
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `updated_at` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
      `is_synced` TINYINT(1) DEFAULT 0 COMMENT 'Synchronisé avec les clients',
      `is_modified` TINYINT(1) DEFAULT 0 COMMENT 'Modifié depuis dernière sync',
      `last_synced_at` DATETIME NULL COMMENT 'Date de dernière synchronisation',
      INDEX `idx_is_active` (`is_active`),
      INDEX `idx_is_synced` (`is_synced`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='En-têtes personnalisés pour les documents (reçus, PDF, rapports)'";
    
    $pdo->exec($sql);
    echo "   ✅ Table créée avec succès\n\n";
    
    // Vérifier si un en-tête existe déjà
    echo "2. Vérification de l'en-tête par défaut...\n";
    $stmt = $pdo->query("SELECT COUNT(*) FROM document_headers WHERE is_active = 1");
    $count = $stmt->fetchColumn();
    
    if ($count == 0) {
        echo "   📝 Insertion de l'en-tête par défaut...\n";
        $insertSql = "INSERT INTO `document_headers` (
          `company_name`,
          `company_slogan`,
          `address`,
          `phone`,
          `email`,
          `website`,
          `is_active`
        ) VALUES (
          'UCASH',
          'Votre partenaire de confiance',
          '',
          '',
          '',
          '',
          1
        )";
        
        $pdo->exec($insertSql);
        echo "   ✅ En-tête par défaut inséré\n";
    } else {
        echo "   ℹ️  Un en-tête actif existe déjà ($count)\n";
    }
    
    echo "\n✅ Initialisation terminée avec succès !\n";
    echo "🔗 Testez l'endpoint: " . (isset($_SERVER['HTTP_HOST']) ? "http://{$_SERVER['HTTP_HOST']}" : "https://safdal.investee-group.com") . "/server/api/document-headers/active\n";
    
} catch (PDOException $e) {
    echo "❌ Erreur: " . $e->getMessage() . "\n";
    exit(1);
}
