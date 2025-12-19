-- Table pour les retenues sur salaire du personnel
CREATE TABLE IF NOT EXISTS retenues_personnel (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reference VARCHAR(50) UNIQUE NOT NULL,
    personnel_id INT NOT NULL,
    personnel_nom VARCHAR(255),
    
    montant_total DECIMAL(15,2) NOT NULL,
    montant_deduit_mensuel DECIMAL(15,2) NOT NULL,
    nombre_mois INT NOT NULL DEFAULT 1,
    mois_debut INT NOT NULL,
    annee_debut INT NOT NULL,
    
    motif VARCHAR(255) NOT NULL,
    type ENUM('Perte', 'Dette', 'Sanction', 'Autre') DEFAULT 'Autre',
    statut ENUM('En_Cours', 'Termine', 'Annule') DEFAULT 'En_Cours',
    
    montant_deja_deduit DECIMAL(15,2) DEFAULT 0.00,
    montant_restant DECIMAL(15,2),
    
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cree_par VARCHAR(100),
    notes TEXT,
    
    last_modified_at TIMESTAMP NULL,
    last_modified_by VARCHAR(100),
    is_synced TINYINT(1) DEFAULT 0,
    synced_at TIMESTAMP NULL,
    
    FOREIGN KEY (personnel_id) REFERENCES personnel(id) ON DELETE CASCADE,
    INDEX idx_personnel (personnel_id),
    INDEX idx_statut (statut),
    INDEX idx_periode (annee_debut, mois_debut),
    INDEX idx_reference (reference)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Trigger pour calculer le montant_restant automatiquement
DELIMITER //
CREATE TRIGGER before_insert_retenue
BEFORE INSERT ON retenues_personnel
FOR EACH ROW
BEGIN
    IF NEW.montant_restant IS NULL THEN
        SET NEW.montant_restant = NEW.montant_total - NEW.montant_deja_deduit;
    END IF;
    
    IF NEW.montant_deduit_mensuel = 0 OR NEW.montant_deduit_mensuel IS NULL THEN
        SET NEW.montant_deduit_mensuel = NEW.montant_total / NEW.nombre_mois;
    END IF;
END//

CREATE TRIGGER before_update_retenue
BEFORE UPDATE ON retenues_personnel
FOR EACH ROW
BEGIN
    SET NEW.montant_restant = NEW.montant_total - NEW.montant_deja_deduit;
    
    -- Changer le statut automatiquement si terminé
    IF NEW.montant_restant <= 0 AND NEW.statut = 'En_Cours' THEN
        SET NEW.statut = 'Termine';
    END IF;
END//
DELIMITER ;
