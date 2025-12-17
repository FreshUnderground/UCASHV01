-- Migration pour ajouter le support des devises multiples
-- Exécuter ce script pour mettre à jour la base de données existante

-- 1. Ajouter les colonnes de soldes par devise à la table sims
ALTER TABLE sims 
ADD COLUMN solde_initial_cdf DECIMAL(15,2) DEFAULT 0.00 AFTER solde_actuel,
ADD COLUMN solde_actuel_cdf DECIMAL(15,2) DEFAULT 0.00 AFTER solde_initial_cdf,
ADD COLUMN solde_initial_usd DECIMAL(15,2) DEFAULT 0.00 AFTER solde_actuel_cdf,
ADD COLUMN solde_actuel_usd DECIMAL(15,2) DEFAULT 0.00 AFTER solde_initial_usd;

-- 2. Créer la table pour les taux de change
CREATE TABLE IF NOT EXISTS currency_rates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL DEFAULT 'CDF',
    to_currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    rate DECIMAL(10,4) NOT NULL DEFAULT 2500.0000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE KEY unique_currency_pair (from_currency, to_currency, is_active)
);

-- 3. Insérer le taux par défaut
INSERT INTO currency_rates (from_currency, to_currency, rate, updated_by) 
VALUES ('CDF', 'USD', 2500.0000, 'system_init')
ON DUPLICATE KEY UPDATE 
rate = VALUES(rate), 
updated_at = CURRENT_TIMESTAMP;

-- 4. Créer la table retraits_virtuels si elle n'existe pas
CREATE TABLE IF NOT EXISTS retraits_virtuels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sim_numero VARCHAR(20) NOT NULL,
    sim_operateur VARCHAR(50),
    shop_source_id INT NOT NULL,
    shop_source_designation VARCHAR(255),
    shop_debiteur_id INT NOT NULL,
    shop_debiteur_designation VARCHAR(255),
    montant DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) DEFAULT 'USD',
    solde_avant DECIMAL(15,2) NOT NULL,
    solde_apres DECIMAL(15,2) NOT NULL,
    agent_id INT NOT NULL,
    agent_username VARCHAR(100),
    notes TEXT,
    statut ENUM('enAttente', 'rembourse', 'annule') DEFAULT 'enAttente',
    date_retrait TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_remboursement TIMESTAMP NULL,
    flot_remboursement_id INT NULL,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_retrait_sim (sim_numero),
    INDEX idx_retrait_shop_source (shop_source_id),
    INDEX idx_retrait_shop_debiteur (shop_debiteur_id),
    INDEX idx_retrait_statut (statut),
    INDEX idx_retrait_devise (devise),
    INDEX idx_retrait_date (date_retrait)
);

-- 5. Créer la table virtual_transactions si elle n'existe pas
CREATE TABLE IF NOT EXISTS virtual_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(100) NOT NULL UNIQUE,
    montant_virtuel DECIMAL(15,2) NOT NULL,
    frais DECIMAL(15,2) DEFAULT 0.00,
    montant_cash DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) DEFAULT 'USD',
    sim_numero VARCHAR(20) NOT NULL,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(255),
    agent_id INT NOT NULL,
    agent_username VARCHAR(100),
    client_nom VARCHAR(255),
    client_telephone VARCHAR(20),
    statut ENUM('enAttente', 'validee', 'annulee') DEFAULT 'enAttente',
    date_enregistrement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_validation TIMESTAMP NULL,
    notes TEXT,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    is_administrative BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_vt_reference (reference),
    INDEX idx_vt_sim (sim_numero),
    INDEX idx_vt_shop (shop_id),
    INDEX idx_vt_statut (statut),
    INDEX idx_vt_devise (devise),
    INDEX idx_vt_date (date_enregistrement)
);

-- 6. Créer la table depot_clients si elle n'existe pas
CREATE TABLE IF NOT EXISTS depot_clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    sim_numero VARCHAR(20) NOT NULL,
    montant DECIMAL(15,2) NOT NULL,
    telephone_client VARCHAR(20) NOT NULL,
    date_depot TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INT NOT NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_depot_shop (shop_id),
    INDEX idx_depot_sim (sim_numero),
    INDEX idx_depot_client (telephone_client),
    INDEX idx_depot_date (date_depot)
);

-- 7. Mettre à jour les données existantes des SIMs
-- Copier les soldes actuels vers USD (compatibilité)
UPDATE sims 
SET 
    solde_initial_usd = solde_initial,
    solde_actuel_usd = solde_actuel,
    solde_initial_cdf = 0.00,
    solde_actuel_cdf = 0.00
WHERE solde_initial_usd IS NULL OR solde_actuel_usd IS NULL;

-- 8. Ajouter des index pour les performances
CREATE INDEX idx_sims_soldes_cdf ON sims(solde_actuel_cdf);
CREATE INDEX idx_sims_soldes_usd ON sims(solde_actuel_usd);
CREATE INDEX idx_virtual_transactions_devise ON virtual_transactions(devise);
CREATE INDEX idx_retraits_virtuels_devise ON retraits_virtuels(devise);

-- 9. Créer une vue pour les soldes consolidés par SIM
CREATE OR REPLACE VIEW sim_balances_consolidated AS
SELECT 
    s.id,
    s.numero,
    s.operateur,
    s.shop_id,
    s.shop_designation,
    s.solde_actuel_cdf,
    s.solde_actuel_usd,
    -- Conversion du solde CDF en USD pour le total
    (s.solde_actuel_cdf / COALESCE(cr.rate, 2500)) + s.solde_actuel_usd as solde_total_usd_equivalent,
    cr.rate as taux_conversion,
    s.statut,
    s.last_modified_at
FROM sims s
LEFT JOIN currency_rates cr ON cr.from_currency = 'CDF' 
    AND cr.to_currency = 'USD' 
    AND cr.is_active = TRUE
WHERE s.statut = 'active';

-- 10. Créer une table pour l'historique des taux de change
CREATE TABLE IF NOT EXISTS currency_rate_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    old_rate DECIMAL(10,4),
    new_rate DECIMAL(10,4) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    reason VARCHAR(255),
    INDEX idx_currency_history_date (changed_at),
    INDEX idx_currency_history_pair (from_currency, to_currency)
);

-- 8. Créer un trigger pour l'historique des taux
DELIMITER $$
CREATE TRIGGER currency_rate_history_trigger
AFTER UPDATE ON currency_rates
FOR EACH ROW
BEGIN
    IF OLD.rate != NEW.rate THEN
        INSERT INTO currency_rate_history 
        (from_currency, to_currency, old_rate, new_rate, changed_by, reason)
        VALUES 
        (NEW.from_currency, NEW.to_currency, OLD.rate, NEW.rate, NEW.updated_by, 'Rate updated');
    END IF;
END$$
DELIMITER ;

-- 9. Ajouter des contraintes de validation
ALTER TABLE sims 
ADD CONSTRAINT chk_solde_cdf_positive CHECK (solde_actuel_cdf >= 0),
ADD CONSTRAINT chk_solde_usd_positive CHECK (solde_actuel_usd >= 0);

ALTER TABLE currency_rates 
ADD CONSTRAINT chk_rate_positive CHECK (rate > 0);

-- 10. Créer des vues pour les statistiques par devise
CREATE OR REPLACE VIEW sim_stats_by_currency AS
SELECT 
    s.shop_id,
    s.shop_designation,
    s.operateur,
    COUNT(*) as total_sims,
    SUM(s.solde_actuel_cdf) as total_solde_cdf,
    SUM(s.solde_actuel_usd) as total_solde_usd,
    SUM((s.solde_actuel_cdf / COALESCE(cr.rate, 2500)) + s.solde_actuel_usd) as total_solde_usd_equivalent
FROM sims s
LEFT JOIN currency_rates cr ON cr.from_currency = 'CDF' 
    AND cr.to_currency = 'USD' 
    AND cr.is_active = TRUE
WHERE s.statut = 'active'
GROUP BY s.shop_id, s.shop_designation, s.operateur;

-- Afficher un résumé des modifications
SELECT 'Migration terminée - Support double devise ajouté' as status;
SELECT COUNT(*) as sims_updated FROM sims WHERE solde_actuel_usd IS NOT NULL;
SELECT rate as taux_cdf_usd FROM currency_rates WHERE from_currency = 'CDF' AND to_currency = 'USD' AND is_active = TRUE;
