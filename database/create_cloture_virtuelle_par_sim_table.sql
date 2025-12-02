-- Création de la table cloture_virtuelle_par_sim
-- Cette table stocke les clôtures quotidiennes détaillées par SIM

CREATE TABLE IF NOT EXISTS `cloture_virtuelle_par_sim` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `sim_numero` VARCHAR(50) NOT NULL,
  `operateur` VARCHAR(50) NOT NULL,
  `date_cloture` DATE NOT NULL,
  
  -- Soldes
  `solde_anterieur` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Solde de la SIM au début de la journée',
  `solde_actuel` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Solde de la SIM à la clôture',
  
  -- Cash Disponible
  `cash_disponible` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Cash physique disponible pour cette SIM',
  
  -- Frais
  `frais_anterieur` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Frais accumulés avant cette journée',
  `frais_du_jour` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Frais générés aujourd\'hui',
  `frais_total` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Total des frais (antérieur + du jour)',
  
  -- Transactions du jour
  `nombre_captures` INT NOT NULL DEFAULT 0 COMMENT 'Nombre de captures créées',
  `montant_captures` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant virtuel des captures',
  `nombre_servies` INT NOT NULL DEFAULT 0 COMMENT 'Nombre de transactions servies',
  `montant_servies` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant virtuel servi',
  `cash_servi` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Cash physique servi aux clients',
  `nombre_en_attente` INT NOT NULL DEFAULT 0 COMMENT 'Nombre de transactions en attente',
  `montant_en_attente` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant virtuel en attente',
  
  -- Retraits (Flots virtuels)
  `nombre_retraits` INT NOT NULL DEFAULT 0 COMMENT 'Nombre de retraits/flots virtuels',
  `montant_retraits` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant total des retraits',
  
  -- Dépôts clients
  `nombre_depots` INT NOT NULL DEFAULT 0 COMMENT 'Nombre de dépôts clients',
  `montant_depots` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant total des dépôts clients',
  
  -- Métadonnées
  `cloture_par` VARCHAR(100) NOT NULL COMMENT 'Username de l\'agent qui a clôturé',
  `agent_id` INT NOT NULL COMMENT 'ID de l\'agent qui a clôturé',
  `date_enregistrement` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `notes` TEXT DEFAULT NULL,
  
  -- Synchronisation
  `is_synced` TINYINT(1) DEFAULT 0,
  `synced_at` DATETIME DEFAULT NULL,
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Index pour performance
  INDEX `idx_shop_id` (`shop_id`),
  INDEX `idx_sim_numero` (`sim_numero`),
  INDEX `idx_date_cloture` (`date_cloture`),
  INDEX `idx_shop_date` (`shop_id`, `date_cloture`),
  INDEX `idx_sim_date` (`sim_numero`, `date_cloture`),
  INDEX `idx_synced` (`is_synced`),
  
  -- Contrainte unique: une seule clôture par SIM par jour
  UNIQUE KEY `unique_sim_date` (`sim_numero`, `date_cloture`),
  
  -- Foreign keys
  CONSTRAINT `fk_cloture_sim_shop` 
    FOREIGN KEY (`shop_id`) REFERENCES `shops`(`id`) 
    ON DELETE CASCADE,
  
  CONSTRAINT `fk_cloture_sim_agent` 
    FOREIGN KEY (`agent_id`) REFERENCES `agents`(`id`) 
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commentaire sur la table
ALTER TABLE `cloture_virtuelle_par_sim` 
  COMMENT = 'Clôtures virtuelles quotidiennes détaillées par SIM - Solde, Cash, Frais';
