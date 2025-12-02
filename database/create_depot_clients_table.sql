-- Création de la table depot_clients
-- Cette table stocke les dépôts clients (Cash reçu → Virtuel envoyé)

CREATE TABLE IF NOT EXISTS `depot_clients` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `shop_id` INT NOT NULL,
  `sim_numero` VARCHAR(50) NOT NULL,
  `montant` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `telephone_client` VARCHAR(50) NOT NULL,
  `date_depot` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` INT NOT NULL,
  `is_synced` TINYINT(1) DEFAULT 0,
  `synced_at` DATETIME DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX `idx_shop_id` (`shop_id`),
  INDEX `idx_sim_numero` (`sim_numero`),
  INDEX `idx_date_depot` (`date_depot`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_synced` (`is_synced`),
  
  CONSTRAINT `fk_depot_clients_shop` 
    FOREIGN KEY (`shop_id`) REFERENCES `shops`(`id`) 
    ON DELETE CASCADE,
  
  CONSTRAINT `fk_depot_clients_user` 
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) 
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commentaires sur les colonnes
ALTER TABLE `depot_clients` 
  COMMENT = 'Dépôts clients - Cash reçu en échange de virtuel envoyé';
