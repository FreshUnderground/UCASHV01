-- Table pour stocker les snapshots quotidiens des dettes intershop
-- Évite de recalculer depuis le début à chaque fois

CREATE TABLE IF NOT EXISTS daily_intershop_debt_snapshot (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Identification
  shop_id INTEGER NOT NULL,
  other_shop_id INTEGER NOT NULL,
  date DATE NOT NULL,
  
  -- Soldes quotidiens
  dette_anterieure REAL NOT NULL DEFAULT 0.0,  -- Dette au début de la journée
  creances_du_jour REAL NOT NULL DEFAULT 0.0,  -- Créances ajoutées aujourd'hui
  dettes_du_jour REAL NOT NULL DEFAULT 0.0,    -- Dettes ajoutées aujourd'hui
  solde_cumule REAL NOT NULL DEFAULT 0.0,      -- Solde final (dette_anterieure + creances - dettes)
  
  -- Métadonnées
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Synchronisation
  synced BOOLEAN DEFAULT 0,
  sync_version INTEGER DEFAULT 1,
  
  -- Contrainte d'unicité: un seul snapshot par jour par paire de shops
  UNIQUE(shop_id, other_shop_id, date)
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_daily_debt_shop_date 
  ON daily_intershop_debt_snapshot(shop_id, date);

CREATE INDEX IF NOT EXISTS idx_daily_debt_other_shop 
  ON daily_intershop_debt_snapshot(other_shop_id, date);

CREATE INDEX IF NOT EXISTS idx_daily_debt_sync 
  ON daily_intershop_debt_snapshot(synced);
