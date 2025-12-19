-- ============================================================================
-- PERSONNEL MANAGEMENT SYSTEM - Database Schema
-- Gestion du Personnel (Salaires, Avances, Crédits, Fiches de Paie)
-- Date: 2025-12-17
-- ============================================================================

USE `ucash_db`;

-- ============================================================================
-- TABLE: personnel
-- Description: Employés/Personnel du système (différent des agents)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `personnel` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `matricule` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Numéro matricule unique',
  `nom` VARCHAR(100) NOT NULL,
  `prenom` VARCHAR(100) NOT NULL,
  `telephone` VARCHAR(20) NOT NULL,
  `email` VARCHAR(100) DEFAULT NULL,
  `adresse` TEXT DEFAULT NULL,
  `date_naissance` DATE DEFAULT NULL,
  `lieu_naissance` VARCHAR(100) DEFAULT NULL,
  `sexe` ENUM('M', 'F') DEFAULT 'M',
  `etat_civil` ENUM('Celibataire', 'Marie', 'Divorce', 'Veuf') DEFAULT 'Celibataire',
  `nombre_enfants` INT DEFAULT 0,
  
  -- Informations professionnelles
  `poste` VARCHAR(100) NOT NULL COMMENT 'Fonction/Poste',
  `departement` VARCHAR(100) DEFAULT NULL,
  `shop_id` BIGINT DEFAULT NULL COMMENT 'Shop affecté (si applicable)',
  `date_embauche` DATE NOT NULL,
  `date_fin_contrat` DATE DEFAULT NULL,
  `type_contrat` ENUM('CDI', 'CDD', 'Stage', 'Temporaire') DEFAULT 'CDI',
  `statut` ENUM('Actif', 'Suspendu', 'Conge', 'Demissionne', 'Licencie') DEFAULT 'Actif',
  
  -- Informations salariales
  `salaire_base` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Salaire de base mensuel',
  `devise_salaire` VARCHAR(10) DEFAULT 'USD',
  `prime_transport` DECIMAL(15,2) DEFAULT 0.00,
  `prime_logement` DECIMAL(15,2) DEFAULT 0.00,
  `prime_fonction` DECIMAL(15,2) DEFAULT 0.00,
  `autres_primes` DECIMAL(15,2) DEFAULT 0.00,
  
  -- Informations bancaires
  `numero_compte_bancaire` VARCHAR(50) DEFAULT NULL,
  `banque` VARCHAR(100) DEFAULT NULL,
  
  -- Métadonnées de synchronisation
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_matricule (matricule),
  INDEX idx_nom (nom, prenom),
  INDEX idx_shop_id (shop_id),
  INDEX idx_statut (statut),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  
  -- Contrainte
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Gestion du personnel/employés';

-- ============================================================================
-- TABLE: salaires
-- Description: Paiements de salaires mensuels
-- ============================================================================
CREATE TABLE IF NOT EXISTS `salaires` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `reference` VARCHAR(100) NOT NULL UNIQUE COMMENT 'Référence unique du paiement',
  `personnel_id` BIGINT NOT NULL,
  `mois` INT NOT NULL COMMENT 'Mois (1-12)',
  `annee` INT NOT NULL COMMENT 'Année',
  `periode` VARCHAR(20) NOT NULL COMMENT 'MM/YYYY',
  
  -- Composantes du salaire
  `salaire_base` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `prime_transport` DECIMAL(15,2) DEFAULT 0.00,
  `prime_logement` DECIMAL(15,2) DEFAULT 0.00,
  `prime_fonction` DECIMAL(15,2) DEFAULT 0.00,
  `autres_primes` DECIMAL(15,2) DEFAULT 0.00,
  `heures_supplementaires` DECIMAL(15,2) DEFAULT 0.00,
  `bonus` DECIMAL(15,2) DEFAULT 0.00,
  
  -- Déductions
  `avances_deduites` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant des avances déduites',
  `credits_deduits` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant des crédits déduits',
  `impots` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Impôts sur le revenu',
  `cotisation_cnss` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Cotisation CNSS/sécurité sociale',
  `autres_deductions` DECIMAL(15,2) DEFAULT 0.00,
  
  -- Calculs
  `salaire_brut` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Total avant déductions',
  `total_deductions` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `salaire_net` DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Montant à payer',
  
  `devise` VARCHAR(10) DEFAULT 'USD',
  
  -- Informations de paiement
  `date_paiement` DATE DEFAULT NULL,
  `mode_paiement` ENUM('Especes', 'Virement', 'Cheque', 'Mobile_Money') DEFAULT 'Especes',
  `statut` ENUM('En_Attente', 'Paye', 'Partiel', 'Annule') DEFAULT 'En_Attente',
  `montant_paye` DECIMAL(15,2) DEFAULT 0.00,
  
  `notes` TEXT DEFAULT NULL,
  `agent_paiement` VARCHAR(100) DEFAULT NULL COMMENT 'Agent qui a effectué le paiement',
  
  -- Métadonnées
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_personnel_id (personnel_id),
  INDEX idx_reference (reference),
  INDEX idx_periode (annee, mois),
  INDEX idx_statut (statut),
  INDEX idx_date_paiement (date_paiement),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  UNIQUE KEY unique_personnel_periode (personnel_id, mois, annee),
  
  -- Contraintes
  FOREIGN KEY (personnel_id) REFERENCES personnel(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Paiements de salaires mensuels';

-- ============================================================================
-- TABLE: avances_personnel
-- Description: Avances sur salaire accordées aux employés
-- ============================================================================
CREATE TABLE IF NOT EXISTS `avances_personnel` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `reference` VARCHAR(100) NOT NULL UNIQUE,
  `personnel_id` BIGINT NOT NULL,
  `montant` DECIMAL(15,2) NOT NULL,
  `devise` VARCHAR(10) DEFAULT 'USD',
  `date_avance` DATE NOT NULL,
  
  -- Remboursement
  `montant_rembourse` DECIMAL(15,2) DEFAULT 0.00,
  `montant_restant` DECIMAL(15,2) NOT NULL,
  `statut` ENUM('En_Cours', 'Rembourse', 'Annule') DEFAULT 'En_Cours',
  `mode_remboursement` ENUM('Mensuel', 'Unique', 'Progressif') DEFAULT 'Mensuel',
  `nombre_mois_remboursement` INT DEFAULT 1 COMMENT 'Nombre de mois pour rembourser',
  
  `motif` TEXT DEFAULT NULL,
  `notes` TEXT DEFAULT NULL,
  `accorde_par` VARCHAR(100) DEFAULT NULL COMMENT 'Agent qui a accordé l\'avance',
  
  -- Métadonnées
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_personnel_id (personnel_id),
  INDEX idx_reference (reference),
  INDEX idx_statut (statut),
  INDEX idx_date_avance (date_avance),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  
  -- Contraintes
  FOREIGN KEY (personnel_id) REFERENCES personnel(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Avances sur salaire';

-- ============================================================================
-- TABLE: credits_personnel
-- Description: Crédits accordés aux employés (différent des avances)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `credits_personnel` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `reference` VARCHAR(100) NOT NULL UNIQUE,
  `personnel_id` BIGINT NOT NULL,
  `montant_credit` DECIMAL(15,2) NOT NULL,
  `devise` VARCHAR(10) DEFAULT 'USD',
  `taux_interet` DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Taux d\'intérêt annuel (%)',
  `date_octroi` DATE NOT NULL,
  `date_echeance` DATE NOT NULL,
  
  -- Remboursement
  `montant_rembourse` DECIMAL(15,2) DEFAULT 0.00,
  `interets_payes` DECIMAL(15,2) DEFAULT 0.00,
  `montant_restant` DECIMAL(15,2) NOT NULL,
  `statut` ENUM('En_Cours', 'Rembourse', 'En_Retard', 'Annule') DEFAULT 'En_Cours',
  `duree_mois` INT NOT NULL COMMENT 'Durée du crédit en mois',
  `mensualite` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant mensuel à rembourser',
  
  `motif` TEXT DEFAULT NULL,
  `garanties` TEXT DEFAULT NULL COMMENT 'Garanties apportées',
  `notes` TEXT DEFAULT NULL,
  `accorde_par` VARCHAR(100) DEFAULT NULL,
  
  -- Métadonnées
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_personnel_id (personnel_id),
  INDEX idx_reference (reference),
  INDEX idx_statut (statut),
  INDEX idx_date_octroi (date_octroi),
  INDEX idx_date_echeance (date_echeance),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  
  -- Contraintes
  FOREIGN KEY (personnel_id) REFERENCES personnel(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Crédits accordés au personnel';

-- ============================================================================
-- TABLE: remboursements_credits
-- Description: Historique des remboursements de crédits
-- ============================================================================
CREATE TABLE IF NOT EXISTS `remboursements_credits` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `credit_id` BIGINT NOT NULL,
  `reference` VARCHAR(100) NOT NULL UNIQUE,
  `montant_principal` DECIMAL(15,2) NOT NULL,
  `montant_interet` DECIMAL(15,2) DEFAULT 0.00,
  `montant_total` DECIMAL(15,2) NOT NULL,
  `date_remboursement` DATE NOT NULL,
  `mode_paiement` ENUM('Especes', 'Virement', 'Cheque', 'Deduction_Salaire') DEFAULT 'Deduction_Salaire',
  `notes` TEXT DEFAULT NULL,
  
  -- Métadonnées
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_credit_id (credit_id),
  INDEX idx_date_remboursement (date_remboursement),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  
  -- Contraintes
  FOREIGN KEY (credit_id) REFERENCES credits_personnel(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Historique des remboursements de crédits';

-- ============================================================================
-- TABLE: fiches_paie
-- Description: Fiches de paie générées (pour archivage et impression)
-- ============================================================================
CREATE TABLE IF NOT EXISTS `fiches_paie` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `salaire_id` BIGINT NOT NULL,
  `personnel_id` BIGINT NOT NULL,
  `reference` VARCHAR(100) NOT NULL UNIQUE,
  `periode` VARCHAR(20) NOT NULL COMMENT 'MM/YYYY',
  `date_generation` DATETIME NOT NULL,
  `genere_par` VARCHAR(100) DEFAULT NULL,
  
  -- Contenu de la fiche (JSON ou PDF path)
  `contenu_json` TEXT DEFAULT NULL COMMENT 'Données complètes en JSON',
  `pdf_path` VARCHAR(255) DEFAULT NULL COMMENT 'Chemin vers le PDF généré',
  
  `statut` ENUM('Brouillon', 'Valide', 'Envoye') DEFAULT 'Valide',
  
  -- Métadonnées
  `last_modified_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_modified_by` VARCHAR(100) DEFAULT 'system',
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `is_synced` BOOLEAN DEFAULT FALSE,
  `synced_at` DATETIME NULL,
  
  -- Index
  INDEX idx_salaire_id (salaire_id),
  INDEX idx_personnel_id (personnel_id),
  INDEX idx_reference (reference),
  INDEX idx_periode (periode),
  INDEX idx_date_generation (date_generation),
  INDEX idx_last_modified (last_modified_at),
  INDEX idx_synced (is_synced, synced_at),
  UNIQUE KEY unique_salaire (salaire_id),
  
  -- Contraintes
  FOREIGN KEY (salaire_id) REFERENCES salaires(id) ON DELETE CASCADE,
  FOREIGN KEY (personnel_id) REFERENCES personnel(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Fiches de paie générées';

-- ============================================================================
-- Insertion de données de test (optionnel)
-- ============================================================================

-- Personnel de test
INSERT INTO `personnel` (`matricule`, `nom`, `prenom`, `telephone`, `email`, `poste`, `date_embauche`, `salaire_base`, `statut`) VALUES
('EMP001', 'MUKENDI', 'Jean', '+243999111222', 'jean.mukendi@ucash.com', 'Caissier', '2024-01-15', 300.00, 'Actif'),
('EMP002', 'KABILA', 'Marie', '+243999222333', 'marie.kabila@ucash.com', 'Comptable', '2024-02-01', 500.00, 'Actif'),
('EMP003', 'TSHISEKEDI', 'Paul', '+243999333444', 'paul.tshisekedi@ucash.com', 'Superviseur', '2023-11-20', 700.00, 'Actif');

-- ============================================================================
-- Triggers pour mise à jour automatique
-- ============================================================================

DELIMITER //

-- Trigger pour calculer le salaire brut automatiquement
CREATE TRIGGER `before_salaire_insert` BEFORE INSERT ON `salaires`
FOR EACH ROW
BEGIN
  SET NEW.salaire_brut = NEW.salaire_base + NEW.prime_transport + NEW.prime_logement + 
                         NEW.prime_fonction + NEW.autres_primes + NEW.heures_supplementaires + NEW.bonus;
  SET NEW.total_deductions = NEW.avances_deduites + NEW.credits_deduits + NEW.impots + 
                             NEW.cotisation_cnss + NEW.autres_deductions;
  SET NEW.salaire_net = NEW.salaire_brut - NEW.total_deductions;
  
  IF NEW.reference IS NULL OR NEW.reference = '' THEN
    SET NEW.reference = CONCAT('SAL-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', FLOOR(RAND() * 1000));
  END IF;
END//

CREATE TRIGGER `before_salaire_update` BEFORE UPDATE ON `salaires`
FOR EACH ROW
BEGIN
  SET NEW.salaire_brut = NEW.salaire_base + NEW.prime_transport + NEW.prime_logement + 
                         NEW.prime_fonction + NEW.autres_primes + NEW.heures_supplementaires + NEW.bonus;
  SET NEW.total_deductions = NEW.avances_deduites + NEW.credits_deduits + NEW.impots + 
                             NEW.cotisation_cnss + NEW.autres_deductions;
  SET NEW.salaire_net = NEW.salaire_brut - NEW.total_deductions;
END//

-- Trigger pour calculer le montant restant des avances
CREATE TRIGGER `before_avance_update` BEFORE UPDATE ON `avances_personnel`
FOR EACH ROW
BEGIN
  SET NEW.montant_restant = NEW.montant - NEW.montant_rembourse;
  
  IF NEW.montant_restant <= 0 THEN
    SET NEW.statut = 'Rembourse';
    SET NEW.montant_restant = 0;
  END IF;
END//

-- Trigger pour calculer le montant restant des crédits
CREATE TRIGGER `before_credit_update` BEFORE UPDATE ON `credits_personnel`
FOR EACH ROW
BEGIN
  SET NEW.montant_restant = NEW.montant_credit - NEW.montant_rembourse;
  
  IF NEW.montant_restant <= 0 THEN
    SET NEW.statut = 'Rembourse';
    SET NEW.montant_restant = 0;
  ELSEIF NEW.date_echeance < CURDATE() AND NEW.montant_restant > 0 THEN
    SET NEW.statut = 'En_Retard';
  END IF;
END//

DELIMITER ;

-- ============================================================================
-- Vues utiles pour reporting
-- ============================================================================

-- Vue: Personnel actif avec salaire et dettes
CREATE OR REPLACE VIEW `v_personnel_actif` AS
SELECT 
  p.id,
  p.matricule,
  CONCAT(p.nom, ' ', p.prenom) AS nom_complet,
  p.telephone,
  p.poste,
  p.departement,
  s.designation AS shop,
  p.salaire_base,
  p.devise_salaire,
  p.date_embauche,
  p.statut,
  IFNULL(SUM(a.montant_restant), 0) AS total_avances_restantes,
  IFNULL(SUM(c.montant_restant), 0) AS total_credits_restants
FROM personnel p
LEFT JOIN shops s ON p.shop_id = s.id
LEFT JOIN avances_personnel a ON p.id = a.personnel_id AND a.statut = 'En_Cours'
LEFT JOIN credits_personnel c ON p.id = c.personnel_id AND c.statut IN ('En_Cours', 'En_Retard')
WHERE p.statut = 'Actif'
GROUP BY p.id;

-- Vue: Rapport mensuel des salaires
CREATE OR REPLACE VIEW `v_rapport_salaires_mensuel` AS
SELECT 
  s.periode,
  s.annee,
  s.mois,
  COUNT(DISTINCT s.personnel_id) AS nombre_employes,
  SUM(s.salaire_brut) AS total_salaire_brut,
  SUM(s.total_deductions) AS total_deductions,
  SUM(s.salaire_net) AS total_salaire_net,
  SUM(s.montant_paye) AS total_paye,
  SUM(s.salaire_net - s.montant_paye) AS total_impaye,
  COUNT(CASE WHEN s.statut = 'Paye' THEN 1 END) AS nombre_payes,
  COUNT(CASE WHEN s.statut = 'En_Attente' THEN 1 END) AS nombre_en_attente
FROM salaires s
GROUP BY s.periode, s.annee, s.mois
ORDER BY s.annee DESC, s.mois DESC;

-- ============================================================================
-- Indexes pour optimisation des requêtes
-- ============================================================================

-- Index composés pour recherches fréquentes
CREATE INDEX idx_personnel_actif ON personnel(statut, shop_id);
CREATE INDEX idx_salaires_periode_statut ON salaires(annee, mois, statut);
CREATE INDEX idx_avances_statut_personnel ON avances_personnel(statut, personnel_id);
CREATE INDEX idx_credits_statut_personnel ON credits_personnel(statut, personnel_id);

-- ============================================================================
-- Fin du script
-- ============================================================================

SELECT '✅ Tables de gestion du personnel créées avec succès!' AS Status;
