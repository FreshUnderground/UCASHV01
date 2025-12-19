-- ============================================================================
-- MISE À JOUR AVANCES - AJOUT MOIS/ANNÉE
-- Permet de déduire les avances selon le mois de paiement
-- ============================================================================

USE ucash;

-- ============================================================================
-- 1. AJOUT COLONNES MOIS/ANNÉE DANS TABLE AVANCES
-- ============================================================================

-- Ajout colonne mois_avance (mois pour lequel l'avance est accordée)
ALTER TABLE `avances_personnel` 
ADD COLUMN `mois_avance` INT DEFAULT NULL COMMENT 'Mois pour lequel l\'avance est donnée' AFTER `date_avance`;

-- Ajout colonne annee_avance (année pour laquelle l'avance est accordée)
ALTER TABLE `avances_personnel` 
ADD COLUMN `annee_avance` INT DEFAULT NULL COMMENT 'Année pour laquelle l\'avance est donnée' AFTER `mois_avance`;

-- ============================================================================
-- 2. MISE À JOUR DES DONNÉES EXISTANTES
-- ============================================================================

-- Remplir mois_avance et annee_avance avec les valeurs de date_avance pour les avances existantes
UPDATE `avances_personnel` 
SET 
  `mois_avance` = MONTH(`date_avance`),
  `annee_avance` = YEAR(`date_avance`)
WHERE `mois_avance` IS NULL OR `annee_avance` IS NULL;

-- ============================================================================
-- 3. INDEX POUR OPTIMISATION DES REQUÊTES
-- ============================================================================

-- Index composite pour recherches rapides par personnel/période
ALTER TABLE `avances_personnel` 
ADD INDEX `idx_personnel_periode` (`personnel_id`, `annee_avance`, `mois_avance`);

-- Index pour recherches par période
ALTER TABLE `avances_personnel` 
ADD INDEX `idx_periode` (`annee_avance`, `mois_avance`);

-- ============================================================================
-- 4. TRIGGER POUR AUTO-REMPLISSAGE (optionnel)
-- ============================================================================

DROP TRIGGER IF EXISTS `before_avance_insert`;

DELIMITER //

CREATE TRIGGER `before_avance_insert` BEFORE INSERT ON `avances_personnel`
FOR EACH ROW
BEGIN
  -- Si mois_avance ou annee_avance n'est pas fourni, utiliser la date_avance
  IF NEW.mois_avance IS NULL THEN
    SET NEW.mois_avance = MONTH(NEW.date_avance);
  END IF;
  
  IF NEW.annee_avance IS NULL THEN
    SET NEW.annee_avance = YEAR(NEW.date_avance);
  END IF;
END//

DELIMITER ;

-- ============================================================================
-- 5. EXEMPLES DE REQUÊTES
-- ============================================================================

-- Afficher toutes les avances avec leur période
SELECT 
  personnel_id,
  reference,
  montant,
  DATE_FORMAT(date_avance, '%d/%m/%Y') as date_avance,
  CONCAT(mois_avance, '/', annee_avance) as periode_avance,
  mode_remboursement,
  nombre_mois_remboursement,
  montant_restant,
  statut
FROM avances_personnel
ORDER BY annee_avance DESC, mois_avance DESC;

-- Avances à déduire pour un mois donné (exemple: Janvier 2025)
SELECT 
  a.reference,
  a.personnel_id,
  a.montant,
  a.mois_avance,
  a.annee_avance,
  a.mode_remboursement,
  CASE 
    WHEN a.mode_remboursement = 'Unique' AND a.mois_avance = 1 AND a.annee_avance = 2025 
      THEN a.montant_restant
    WHEN a.mode_remboursement = 'Mensuel' 
      THEN a.montant / a.nombre_mois_remboursement
    ELSE 0
  END as montant_a_deduire
FROM avances_personnel a
WHERE a.statut = 'En_Cours'
  AND (a.annee_avance < 2025 OR (a.annee_avance = 2025 AND a.mois_avance <= 1));

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================

SELECT 'Mise à jour avances terminée avec succès!' AS status;
SELECT 'Les colonnes mois_avance et annee_avance ont été ajoutées.' AS info;
SELECT 'Les avances existantes ont été mises à jour automatiquement.' AS info;
