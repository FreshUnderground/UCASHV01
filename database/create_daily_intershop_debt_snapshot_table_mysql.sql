-- Table pour stocker les snapshots quotidiens des dettes intershop
-- Évite de recalculer depuis le début à chaque fois
-- Version MySQL/MariaDB

CREATE TABLE IF NOT EXISTS daily_intershop_debt_snapshot (
  id INT AUTO_INCREMENT PRIMARY KEY,
  
  -- Identification
  shop_id INT NOT NULL,
  other_shop_id INT NOT NULL,
  date DATE NOT NULL,
  
  -- Soldes quotidiens
  dette_anterieure DECIMAL(15,2) NOT NULL DEFAULT 0.0,
  creances_du_jour DECIMAL(15,2) NOT NULL DEFAULT 0.0,
  dettes_du_jour DECIMAL(15,2) NOT NULL DEFAULT 0.0,
  solde_cumule DECIMAL(15,2) NOT NULL DEFAULT 0.0,
  
  -- Métadonnées
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Synchronisation
  synced TINYINT(1) DEFAULT 0,
  sync_version INT DEFAULT 1,
  
  -- Contrainte d'unicité: un seul snapshot par jour par paire de shops
  UNIQUE KEY unique_shop_pair_date (shop_id, other_shop_id, date),
  
  -- Index pour recherche rapide
  INDEX idx_shop_date (shop_id, date),
  INDEX idx_other_shop_date (other_shop_id, date),
  INDEX idx_sync (synced)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
