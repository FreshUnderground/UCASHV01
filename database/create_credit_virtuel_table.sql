-- Table pour la gestion des crédits virtuels entre shops/partenaires
-- Permet de faire sortir du crédit virtuel avec paiement ultérieur

CREATE TABLE IF NOT EXISTS credit_virtuel (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(50) NOT NULL UNIQUE,
    montant_credit DECIMAL(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'USD',
    
    -- Informations bénéficiaire
    beneficiaire_nom VARCHAR(255) NOT NULL,
    beneficiaire_telephone VARCHAR(20),
    beneficiaire_adresse TEXT,
    type_beneficiaire ENUM('shop', 'partenaire', 'autre') NOT NULL DEFAULT 'shop',
    
    -- Informations SIM et shop émetteur
    sim_numero VARCHAR(20) NOT NULL,
    shop_id INT NOT NULL,
    shop_designation VARCHAR(255),
    
    -- Informations agent
    agent_id INT NOT NULL,
    agent_username VARCHAR(100),
    
    -- Statut du crédit
    statut ENUM('accorde', 'partiellement_paye', 'paye', 'annule', 'en_retard') NOT NULL DEFAULT 'accorde',
    
    -- Dates et tracking
    date_sortie DATETIME NOT NULL,
    date_paiement DATETIME NULL,
    date_echeance DATETIME NULL,
    notes TEXT,
    
    -- Informations de paiement
    montant_paye DECIMAL(15,2) DEFAULT 0.00,
    mode_paiement ENUM('cash', 'mobile_money', 'virement') NULL,
    reference_paiement VARCHAR(100) NULL,
    
    -- Synchronization
    last_modified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    is_synced BOOLEAN DEFAULT FALSE,
    synced_at DATETIME NULL,
    
    -- Index pour optimiser les requêtes
    INDEX idx_reference (reference),
    INDEX idx_shop_id (shop_id),
    INDEX idx_sim_numero (sim_numero),
    INDEX idx_statut (statut),
    INDEX idx_date_sortie (date_sortie),
    INDEX idx_date_echeance (date_echeance),
    INDEX idx_beneficiaire (beneficiaire_nom),
    INDEX idx_sync (is_synced, last_modified_at)
);

-- Contraintes pour assurer l'intégrité des données
ALTER TABLE credit_virtuel 
ADD CONSTRAINT chk_montant_credit_positive CHECK (montant_credit > 0),
ADD CONSTRAINT chk_montant_paye_positive CHECK (montant_paye >= 0),
ADD CONSTRAINT chk_montant_paye_not_exceed CHECK (montant_paye <= montant_credit);

-- Trigger pour mettre à jour automatiquement le statut en fonction des paiements
DELIMITER //
CREATE TRIGGER update_credit_status_after_payment
    BEFORE UPDATE ON credit_virtuel
    FOR EACH ROW
BEGIN
    -- Mettre à jour le statut en fonction du montant payé
    IF NEW.montant_paye >= NEW.montant_credit THEN
        SET NEW.statut = 'paye';
        IF NEW.date_paiement IS NULL THEN
            SET NEW.date_paiement = NOW();
        END IF;
    ELSEIF NEW.montant_paye > 0 THEN
        SET NEW.statut = 'partiellement_paye';
    END IF;
    
    -- Vérifier si le crédit est en retard
    IF NEW.date_echeance IS NOT NULL 
       AND NOW() > NEW.date_echeance 
       AND NEW.statut NOT IN ('paye', 'annule') THEN
        SET NEW.statut = 'en_retard';
    END IF;
END//
DELIMITER ;

-- Commentaires sur la table
ALTER TABLE credit_virtuel COMMENT = 'Gestion des crédits virtuels accordés aux shops/partenaires';
