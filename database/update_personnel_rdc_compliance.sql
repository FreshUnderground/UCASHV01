-- ============================================================================
-- MISE À JOUR CONFORMITÉ RDC - GESTION DU PERSONNEL
-- Ajout des champs obligatoires selon la réglementation RDC
-- Arrêté ministériel du 8 août 2008 - Livre de paie
-- ============================================================================

USE ucash;

-- ============================================================================
-- 1. MISE À JOUR TABLE PERSONNEL
-- ============================================================================

-- Ajout Numéro INSS (Obligatoire RDC)
ALTER TABLE `personnel` 
ADD COLUMN `numero_inss` VARCHAR(50) NULL COMMENT 'Numéro INSS (Institut National de Sécurité Sociale)' AFTER `nombre_enfants`;

-- Ajout Catégorie Professionnelle (Classification RDC)
ALTER TABLE `personnel` 
ADD COLUMN `categorie_professionnelle` VARCHAR(100) DEFAULT 'Non classe' COMMENT 'Catégorie selon classification RDC' AFTER `numero_inss`;

-- Ajout Avantages en Nature
ALTER TABLE `personnel` 
ADD COLUMN `avantage_nature_logement` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Valeur logement fourni (avantage en nature)' AFTER `autres_primes`,
ADD COLUMN `avantage_nature_voiture` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Valeur voiture de service (avantage en nature)' AFTER `avantage_nature_logement`,
ADD COLUMN `autres_avantages_nature` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Autres avantages évaluables en espèces' AFTER `avantage_nature_voiture`;

-- ============================================================================
-- 2. MISE À JOUR TABLE SALAIRES
-- ============================================================================

-- Ajout Avantages en Nature dans salaires
ALTER TABLE `salaires`
ADD COLUMN `avantage_nature_logement` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Avantage logement période' AFTER `bonus`,
ADD COLUMN `avantage_nature_voiture` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Avantage voiture période' AFTER `avantage_nature_logement`,
ADD COLUMN `autres_avantages_nature` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Autres avantages période' AFTER `avantage_nature_voiture`;

-- Ajout Suppléments RDC
ALTER TABLE `salaires`
ADD COLUMN `supplement_weekend` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Supplément travail week-end' AFTER `autres_avantages_nature`,
ADD COLUMN `supplement_jours_feries` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Supplément jours fériés' AFTER `supplement_weekend`,
ADD COLUMN `allocations_familiales` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Allocations familiales selon nombre enfants' AFTER `supplement_jours_feries`;

-- Ajout Déductions spécifiques RDC
ALTER TABLE `salaires`
ADD COLUMN `retenue_disciplinaire` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Retenues pour sanctions disciplinaires' AFTER `autres_deductions`,
ADD COLUMN `retenue_absences` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Retenues pour absences non justifiées' AFTER `retenue_disciplinaire`;

-- Ajout Net Imposable (pour déclaration fiscale IPR)
ALTER TABLE `salaires`
ADD COLUMN `net_imposable` DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Net imposable pour IPR (brut - CNSS)' AFTER `salaire_net`;

-- ============================================================================
-- 3. MISE À JOUR DES TRIGGERS POUR CALCULS AUTOMATIQUES
-- ============================================================================

DROP TRIGGER IF EXISTS `before_salaire_insert`;
DROP TRIGGER IF EXISTS `before_salaire_update`;

DELIMITER //

-- Trigger INSERT avec nouveaux champs RDC
CREATE TRIGGER `before_salaire_insert` BEFORE INSERT ON `salaires`
FOR EACH ROW
BEGIN
  -- Calcul salaire brut (base + primes + suppléments + avantages en nature)
  SET NEW.salaire_brut = NEW.salaire_base + 
                         NEW.prime_transport + 
                         NEW.prime_logement + 
                         NEW.prime_fonction + 
                         NEW.autres_primes + 
                         NEW.heures_supplementaires + 
                         NEW.bonus +
                         NEW.avantage_nature_logement +
                         NEW.avantage_nature_voiture +
                         NEW.autres_avantages_nature +
                         NEW.supplement_weekend +
                         NEW.supplement_jours_feries +
                         NEW.allocations_familiales;
  
  -- Calcul total déductions
  SET NEW.total_deductions = NEW.avances_deduites + 
                             NEW.credits_deduits + 
                             NEW.impots + 
                             NEW.cotisation_cnss + 
                             NEW.autres_deductions +
                             NEW.retenue_disciplinaire +
                             NEW.retenue_absences;
  
  -- Calcul salaire net
  SET NEW.salaire_net = NEW.salaire_brut - NEW.total_deductions;
  
  -- Calcul net imposable (Brut - Cotisation CNSS)
  -- En RDC, les cotisations sociales ne sont pas soumises à l'IPR
  SET NEW.net_imposable = NEW.salaire_brut - NEW.cotisation_cnss;
END//

-- Trigger UPDATE avec nouveaux champs RDC
CREATE TRIGGER `before_salaire_update` BEFORE UPDATE ON `salaires`
FOR EACH ROW
BEGIN
  -- Calcul salaire brut (base + primes + suppléments + avantages en nature)
  SET NEW.salaire_brut = NEW.salaire_base + 
                         NEW.prime_transport + 
                         NEW.prime_logement + 
                         NEW.prime_fonction + 
                         NEW.autres_primes + 
                         NEW.heures_supplementaires + 
                         NEW.bonus +
                         NEW.avantage_nature_logement +
                         NEW.avantage_nature_voiture +
                         NEW.autres_avantages_nature +
                         NEW.supplement_weekend +
                         NEW.supplement_jours_feries +
                         NEW.allocations_familiales;
  
  -- Calcul total déductions
  SET NEW.total_deductions = NEW.avances_deduites + 
                             NEW.credits_deduits + 
                             NEW.impots + 
                             NEW.cotisation_cnss + 
                             NEW.autres_deductions +
                             NEW.retenue_disciplinaire +
                             NEW.retenue_absences;
  
  -- Calcul salaire net
  SET NEW.salaire_net = NEW.salaire_brut - NEW.total_deductions;
  
  -- Calcul net imposable
  SET NEW.net_imposable = NEW.salaire_brut - NEW.cotisation_cnss;
END//

DELIMITER ;

-- ============================================================================
-- 4. DONNÉES DE RÉFÉRENCE - CATÉGORIES PROFESSIONNELLES RDC
-- ============================================================================

-- Table pour les catégories professionnelles (optionnel)
CREATE TABLE IF NOT EXISTS `categories_professionnelles_rdc` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `code` VARCHAR(20) NOT NULL UNIQUE,
  `libelle` VARCHAR(100) NOT NULL,
  `description` TEXT,
  `salaire_min` DECIMAL(15,2) DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des catégories courantes RDC
INSERT INTO `categories_professionnelles_rdc` (`code`, `libelle`, `description`, `salaire_min`) VALUES
('CAT_1', 'Catégorie 1 - Manoeuvres', 'Personnel non qualifié', 0),
('CAT_2', 'Catégorie 2 - Ouvriers spécialisés', 'Personnel avec spécialisation de base', 0),
('CAT_3', 'Catégorie 3 - Agents de maîtrise', 'Personnel d\'encadrement intermédiaire', 0),
('CAT_4', 'Catégorie 4 - Cadres', 'Personnel d\'encadrement supérieur', 0),
('CAT_5', 'Catégorie 5 - Cadres supérieurs', 'Direction et haute qualification', 0)
ON DUPLICATE KEY UPDATE libelle=VALUES(libelle);

-- ============================================================================
-- 5. INDEX POUR OPTIMISATION
-- ============================================================================

-- Index sur numéro INSS pour recherches rapides
ALTER TABLE `personnel` ADD INDEX `idx_numero_inss` (`numero_inss`);

-- Index sur catégorie professionnelle
ALTER TABLE `personnel` ADD INDEX `idx_categorie_pro` (`categorie_professionnelle`);

-- ============================================================================
-- 6. COMMENTAIRES ET DOCUMENTATION
-- ============================================================================

ALTER TABLE `personnel` COMMENT = 'Personnel conforme réglementation RDC - Arrêté ministériel 8 août 2008';
ALTER TABLE `salaires` COMMENT = 'Salaires conformes bulletin de paie RDC avec tous éléments obligatoires';

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================

SELECT 'Mise à jour conformité RDC terminée avec succès!' AS status;
SELECT 'Les champs suivants ont été ajoutés:' AS info;
SELECT '- Numéro INSS (personnel)' AS champ;
SELECT '- Catégorie professionnelle (personnel)' AS champ;
SELECT '- Avantages en nature (personnel + salaires)' AS champ;
SELECT '- Suppléments weekend/jours fériés (salaires)' AS champ;
SELECT '- Allocations familiales (salaires)' AS champ;
SELECT '- Retenues disciplinaires/absences (salaires)' AS champ;
SELECT '- Net imposable (salaires)' AS champ;
