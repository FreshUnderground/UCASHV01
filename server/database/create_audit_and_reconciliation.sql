-- ============================================================================
-- AUDIT TRAIL - Traçabilité complète de toutes les modifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL COMMENT 'Nom de la table modifiée',
    record_id BIGINT NOT NULL COMMENT 'ID de l''enregistrement modifié',
    action ENUM('CREATE', 'UPDATE', 'DELETE', 'VALIDATE', 'CANCEL') NOT NULL,
    old_values JSON NULL COMMENT 'Valeurs avant modification',
    new_values JSON NULL COMMENT 'Valeurs après modification',
    changed_fields JSON NULL COMMENT 'Liste des champs modifiés',
    user_id INT NULL COMMENT 'ID de l''utilisateur (agent)',
    user_role VARCHAR(50) NULL COMMENT 'Rôle de l''utilisateur',
    username VARCHAR(100) NULL COMMENT 'Nom d''utilisateur',
    shop_id INT NULL COMMENT 'Shop concerné',
    ip_address VARCHAR(45) NULL COMMENT 'Adresse IP',
    device_info VARCHAR(255) NULL COMMENT 'Info appareil (mobile/web)',
    reason TEXT NULL COMMENT 'Raison de la modification',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_table_record (table_name, record_id),
    INDEX idx_table_action (table_name, action),
    INDEX idx_user (user_id),
    INDEX idx_shop (shop_id),
    INDEX idx_created (created_at),
    INDEX idx_table_created (table_name, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='Journal d''audit - Traçabilité de toutes les modifications';

-- ============================================================================
-- RÉCONCILIATION BANCAIRE - Rapprochement système vs réel
-- ============================================================================
CREATE TABLE IF NOT EXISTS reconciliations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    shop_id INT NOT NULL,
    date_reconciliation DATE NOT NULL,
    periode ENUM('DAILY', 'WEEKLY', 'MONTHLY') DEFAULT 'DAILY',
    
    -- CAPITAL SYSTÈME (selon la base de données)
    capital_systeme_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_systeme_airtel DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_systeme_mpesa DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_systeme_orange DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_systeme_total DECIMAL(15,2) NOT NULL DEFAULT 0,
    
    -- CAPITAL RÉEL (compté physiquement)
    capital_reel_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_reel_airtel DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_reel_mpesa DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_reel_orange DECIMAL(15,2) NOT NULL DEFAULT 0,
    capital_reel_total DECIMAL(15,2) NOT NULL DEFAULT 0,
    
    -- ÉCARTS (calculés automatiquement)
    ecart_cash DECIMAL(15,2) GENERATED ALWAYS AS (capital_reel_cash - capital_systeme_cash) STORED,
    ecart_airtel DECIMAL(15,2) GENERATED ALWAYS AS (capital_reel_airtel - capital_systeme_airtel) STORED,
    ecart_mpesa DECIMAL(15,2) GENERATED ALWAYS AS (capital_reel_mpesa - capital_systeme_mpesa) STORED,
    ecart_orange DECIMAL(15,2) GENERATED ALWAYS AS (capital_reel_orange - capital_systeme_orange) STORED,
    ecart_total DECIMAL(15,2) GENERATED ALWAYS AS (capital_reel_total - capital_systeme_total) STORED,
    
    -- POURCENTAGE D'ÉCART
    ecart_pourcentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN capital_systeme_total > 0 THEN ((capital_reel_total - capital_systeme_total) / capital_systeme_total * 100)
            ELSE 0 
        END
    ) STORED,
    
    -- STATUT ET VALIDATION
    statut ENUM('EN_COURS', 'VALIDE', 'ECART_ACCEPTABLE', 'ECART_ALERTE', 'INVESTIGATION') DEFAULT 'EN_COURS',
    notes TEXT NULL COMMENT 'Notes et explications des écarts',
    justification TEXT NULL COMMENT 'Justification des écarts',
    
    -- DEVISE SECONDAIRE (optionnel)
    devise_secondaire VARCHAR(3) NULL,
    capital_systeme_devise2 DECIMAL(15,2) NULL,
    capital_reel_devise2 DECIMAL(15,2) NULL,
    ecart_devise2 DECIMAL(15,2) NULL,
    
    -- ACTIONS CORRECTIVES
    action_corrective_requise BOOLEAN DEFAULT FALSE,
    action_corrective_prise TEXT NULL,
    
    -- MÉTADONNÉES
    created_by INT NULL COMMENT 'Agent qui a créé la réconciliation',
    verified_by INT NULL COMMENT 'Admin qui a vérifié',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP NULL,
    last_modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- SYNCHRONISATION
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP NULL,
    last_modified_by VARCHAR(100) NULL,
    
    FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES agents(id) ON DELETE SET NULL,
    FOREIGN KEY (verified_by) REFERENCES agents(id) ON DELETE SET NULL,
    
    UNIQUE KEY unique_shop_date (shop_id, date_reconciliation),
    INDEX idx_shop_date (shop_id, date_reconciliation),
    INDEX idx_statut (statut),
    INDEX idx_date (date_reconciliation),
    INDEX idx_created (created_at),
    INDEX idx_synced (is_synced)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Rapprochement bancaire - Comparaison capital système vs réel';

-- ============================================================================
-- RECONCILIATION ITEMS - Détails ligne par ligne
-- ============================================================================
CREATE TABLE IF NOT EXISTS reconciliation_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    reconciliation_id BIGINT NOT NULL,
    type ENUM('CASH', 'AIRTEL', 'MPESA', 'ORANGE') NOT NULL,
    
    -- Pour le cash physique
    denomination DECIMAL(10,2) NULL COMMENT 'Valeur billet/pièce (ex: 100, 50, 20)',
    quantite INT NULL COMMENT 'Nombre de billets/pièces',
    sous_total DECIMAL(15,2) NULL COMMENT 'denomination * quantite',
    
    -- Pour E-Money
    reference_transaction VARCHAR(100) NULL COMMENT 'Référence de vérification',
    montant DECIMAL(15,2) NULL,
    
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (reconciliation_id) REFERENCES reconciliations(id) ON DELETE CASCADE,
    INDEX idx_reconciliation (reconciliation_id),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Détails des comptages de réconciliation';

-- ============================================================================
-- VUE : Réconciliations avec écarts significatifs
-- ============================================================================
CREATE OR REPLACE VIEW v_reconciliations_ecarts AS
SELECT 
    r.*,
    s.designation as shop_name,
    CONCAT(a1.nom, ' (', a1.username, ')') as created_by_name,
    CONCAT(a2.nom, ' (', a2.username, ')') as verified_by_name,
    CASE 
        WHEN ABS(r.ecart_pourcentage) > 5 THEN 'CRITIQUE'
        WHEN ABS(r.ecart_pourcentage) > 2 THEN 'ATTENTION'
        WHEN ABS(r.ecart_pourcentage) > 0 THEN 'MINEUR'
        ELSE 'OK'
    END as niveau_alerte
FROM reconciliations r
LEFT JOIN shops s ON r.shop_id = s.id
LEFT JOIN agents a1 ON r.created_by = a1.id
LEFT JOIN agents a2 ON r.verified_by = a2.id
WHERE ABS(r.ecart_pourcentage) > 0
ORDER BY ABS(r.ecart_pourcentage) DESC, r.date_reconciliation DESC;

-- ============================================================================
-- VUE : Résumé des audits par table
-- ============================================================================
CREATE OR REPLACE VIEW v_audit_summary AS
SELECT 
    table_name,
    action,
    COUNT(*) as nb_actions,
    COUNT(DISTINCT user_id) as nb_users,
    COUNT(DISTINCT shop_id) as nb_shops,
    MIN(created_at) as first_action,
    MAX(created_at) as last_action
FROM audit_log
GROUP BY table_name, action
ORDER BY table_name, action;

-- ============================================================================
-- VUE : Réconciliations récentes par shop
-- ============================================================================
CREATE OR REPLACE VIEW v_reconciliations_recent AS
SELECT 
    r.shop_id,
    s.designation as shop_name,
    r.date_reconciliation,
    r.capital_systeme_total,
    r.capital_reel_total,
    r.ecart_total,
    r.ecart_pourcentage,
    r.statut,
    DATEDIFF(CURDATE(), r.date_reconciliation) as jours_depuis_derniere
FROM reconciliations r
INNER JOIN shops s ON r.shop_id = s.id
WHERE r.date_reconciliation = (
    SELECT MAX(date_reconciliation) 
    FROM reconciliations r2 
    WHERE r2.shop_id = r.shop_id
)
ORDER BY r.date_reconciliation DESC;

-- ============================================================================
-- Insérer un exemple de réconciliation pour démonstration
-- ============================================================================
-- (Commenté - à exécuter manuellement si besoin)
-- INSERT INTO reconciliations (
--     shop_id, date_reconciliation, 
--     capital_systeme_cash, capital_systeme_airtel, capital_systeme_mpesa, capital_systeme_orange, capital_systeme_total,
--     capital_reel_cash, capital_reel_airtel, capital_reel_mpesa, capital_reel_orange, capital_reel_total,
--     statut, notes, created_by
-- ) VALUES (
--     1, CURDATE(),
--     10000, 5000, 3000, 2000, 20000,
--     9950, 5000, 3000, 2050, 20000,
--     'VALIDE', 'Écart cash: -50 USD (billet déchiré), Orange: +50 USD (transaction en cours)', 1
-- );

-- ============================================================================
-- Indexes supplémentaires pour performance
-- ============================================================================
ALTER TABLE audit_log ADD INDEX idx_user_created (user_id, created_at);
ALTER TABLE audit_log ADD INDEX idx_shop_created (shop_id, created_at);
ALTER TABLE reconciliations ADD INDEX idx_statut_date (statut, date_reconciliation);

-- ============================================================================
-- Commentaires sur les colonnes importantes
-- ============================================================================
ALTER TABLE audit_log MODIFY COLUMN changed_fields JSON NULL 
    COMMENT 'Liste des champs modifiés: ["montant", "statut"]';
    
ALTER TABLE reconciliations MODIFY COLUMN action_corrective_requise BOOLEAN DEFAULT FALSE
    COMMENT 'TRUE si écart > seuil acceptable (ex: 2%)';

SELECT '✅ Tables AUDIT_LOG et RECONCILIATIONS créées avec succès!' as message;
