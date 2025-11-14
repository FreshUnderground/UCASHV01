-- ============================================================================
-- GUIDE D'INSTALLATION ET MIGRATION - BASE DE DONNÉES UCASH v2.0
-- Support Multi-devises (USD, CDF, UGX)
-- ============================================================================

-- ============================================================================
-- OPTION 1: INSTALLATION NOUVELLE BASE DE DONNÉES (PROJET VIERGE)
-- ============================================================================

/*
Si vous installez UCASH pour la première fois sans données existantes :

1. Créer la base de données :
   CREATE DATABASE ucash CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   USE ucash;

2. Exécuter le script principal :
   SOURCE c:/laragon1/www/UCASHV01/server/database/sync_tables.sql;

3. Insérer les taux de change par défaut :
*/

-- Taux USD → CDF (Franc Congolais)
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('USD', 'CDF', 2500.00, 'ACHAT', TRUE),
('USD', 'CDF', 2550.00, 'VENTE', TRUE),
('USD', 'CDF', 2525.00, 'MOYEN', TRUE);

-- Taux USD → UGX (Shilling Ougandais)
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('USD', 'UGX', 3650.00, 'ACHAT', TRUE),
('USD', 'UGX', 3750.00, 'VENTE', TRUE),
('USD', 'UGX', 3700.00, 'MOYEN', TRUE);

-- Taux croisés CDF ↔ UGX
INSERT INTO taux (devise_source, devise_cible, taux, type, est_actif) VALUES
('CDF', 'UGX', 1.4760, 'ACHAT', TRUE),
('CDF', 'UGX', 1.4706, 'VENTE', TRUE),
('CDF', 'UGX', 1.4653, 'MOYEN', TRUE);

/*
4. Créer un shop de test avec multi-devises :
*/

INSERT INTO shops (
    designation, 
    localisation, 
    devise_principale, 
    devise_secondaire,
    capital_cash,
    capital_cash_devise2
) VALUES (
    'Shop Test Kinshasa',
    'Kinshasa, RDC',
    'USD',
    'CDF',
    1000.00,      -- 1000 USD en cash
    2500000.00    -- 2,500,000 CDF en cash
);

/*
5. Créer un agent admin :
*/

INSERT INTO agents (
    username, 
    password, 
    nom, 
    shop_id, 
    role
) VALUES (
    'admin',
    -- Mot de passe hashé pour 'admin123' (à adapter selon votre système)
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Administrateur',
    1,
    'ADMIN'
);

-- ============================================================================
-- OPTION 2: MIGRATION BASE DE DONNÉES EXISTANTE
-- ============================================================================

/*
Si vous avez déjà une base de données UCASH avec des données :

1. SAUVEGARDER LA BASE DE DONNÉES EXISTANTE :
   mysqldump -u root -p ucash > ucash_backup_$(date +%Y%m%d).sql

2. Se connecter à la base :
   USE ucash;

3. Exécuter le script de migration :
   SOURCE c:/laragon1/www/UCASHV01/server/database/migration_multidevises.sql;

Le script va :
- ✓ Sauvegarder l'ancienne table taux dans taux_backup
- ✓ Migrer vers la nouvelle structure (devise_source, devise_cible)
- ✓ Ajouter les colonnes multi-devises aux shops
- ✓ Ajouter la colonne devise aux opérations
- ✓ Insérer les taux de change par défaut
- ✓ Afficher les statistiques de migration
*/

-- ============================================================================
-- VÉRIFICATIONS POST-MIGRATION
-- ============================================================================

-- 1. Vérifier la structure de la table taux
DESCRIBE taux;

-- Résultat attendu : devise_source, devise_cible, taux, type, date_effet, est_actif

-- 2. Vérifier la structure de la table shops
DESCRIBE shops;

-- Résultat attendu : devise_principale, devise_secondaire, capital_*_devise2

-- 3. Vérifier la structure de la table operations
DESCRIBE operations;

-- Résultat attendu : colonne 'devise' présente

-- 4. Afficher tous les taux actifs
SELECT 
    CONCAT(devise_source, ' → ', devise_cible) as conversion,
    taux,
    type,
    est_actif
FROM taux 
WHERE est_actif = TRUE
ORDER BY devise_source, devise_cible, type;

-- 5. Vérifier les shops avec multi-devises
SELECT 
    id,
    designation,
    devise_principale,
    devise_secondaire,
    capital_cash,
    capital_cash_devise2
FROM shops;

-- ============================================================================
-- CONFIGURATION DES DEVISES PAR SHOP
-- ============================================================================

-- Exemple 1: Shop en RDC avec USD + CDF
UPDATE shops 
SET devise_principale = 'USD',
    devise_secondaire = 'CDF'
WHERE id = 1;

-- Exemple 2: Shop en Ouganda avec USD + UGX
UPDATE shops 
SET devise_principale = 'USD',
    devise_secondaire = 'UGX'
WHERE id = 2;

-- Exemple 3: Shop international avec USD seulement
UPDATE shops 
SET devise_principale = 'USD',
    devise_secondaire = NULL
WHERE id = 3;

-- ============================================================================
-- REQUÊTES UTILES POUR MULTI-DEVISES
-- ============================================================================

-- 1. Calculer le capital total d'un shop en USD
SELECT 
    id,
    designation,
    devise_principale,
    devise_secondaire,
    (capital_cash + capital_airtel_money + capital_mpesa + capital_orange_money) as total_devise_principale,
    CASE 
        WHEN devise_secondaire IS NOT NULL THEN
            (COALESCE(capital_cash_devise2, 0) + 
             COALESCE(capital_airtel_money_devise2, 0) + 
             COALESCE(capital_mpesa_devise2, 0) + 
             COALESCE(capital_orange_money_devise2, 0))
        ELSE NULL
    END as total_devise_secondaire
FROM shops;

-- 2. Statistiques des opérations par devise
SELECT 
    devise,
    COUNT(*) as nombre_operations,
    SUM(montant_brut) as montant_total,
    SUM(commission) as commission_totale,
    AVG(commission) as commission_moyenne
FROM operations
GROUP BY devise
ORDER BY montant_total DESC;

-- 3. Conversions de devises avec les taux actuels
SELECT 
    t1.devise_source as de,
    t1.devise_cible as vers,
    t1.taux as taux_conversion,
    1000 as montant_source,
    (1000 * t1.taux) as montant_converti,
    t1.type
FROM taux t1
WHERE t1.est_actif = TRUE
  AND t1.type = 'MOYEN'
ORDER BY t1.devise_source, t1.devise_cible;

-- 4. Trouver le taux de conversion entre deux devises
DELIMITER $$
CREATE FUNCTION IF NOT EXISTS get_taux_conversion(
    p_devise_source VARCHAR(10),
    p_devise_cible VARCHAR(10),
    p_type VARCHAR(50)
) RETURNS DECIMAL(10,4)
DETERMINISTIC
BEGIN
    DECLARE v_taux DECIMAL(10,4);
    
    -- Recherche directe
    SELECT taux INTO v_taux
    FROM taux
    WHERE devise_source = p_devise_source
      AND devise_cible = p_devise_cible
      AND type = p_type
      AND est_actif = TRUE
    LIMIT 1;
    
    -- Si trouvé, retourner
    IF v_taux IS NOT NULL THEN
        RETURN v_taux;
    END IF;
    
    -- Sinon, chercher l'inverse
    SELECT (1 / taux) INTO v_taux
    FROM taux
    WHERE devise_source = p_devise_cible
      AND devise_cible = p_devise_source
      AND type = p_type
      AND est_actif = TRUE
    LIMIT 1;
    
    RETURN COALESCE(v_taux, 0);
END$$
DELIMITER ;

-- Exemple d'utilisation de la fonction
SELECT get_taux_conversion('USD', 'CDF', 'MOYEN') as taux_usd_to_cdf;
SELECT get_taux_conversion('CDF', 'USD', 'MOYEN') as taux_cdf_to_usd;

-- ============================================================================
-- MAINTENANCE ET OPTIMISATION
-- ============================================================================

-- 1. Mettre à jour les taux de change (à faire quotidiennement)
UPDATE taux 
SET taux = 2550.00, 
    date_effet = NOW(),
    last_modified_at = NOW()
WHERE devise_source = 'USD' 
  AND devise_cible = 'CDF' 
  AND type = 'MOYEN';

-- 2. Désactiver les anciens taux
UPDATE taux 
SET est_actif = FALSE,
    last_modified_at = NOW()
WHERE date_effet < DATE_SUB(NOW(), INTERVAL 30 DAY)
  AND est_actif = TRUE;

-- 3. Nettoyer les données
OPTIMIZE TABLE taux;
OPTIMIZE TABLE shops;
OPTIMIZE TABLE operations;

-- 4. Vérifier l'intégrité des données
SELECT 
    'Shops avec devise_secondaire mais sans capitaux' as probleme,
    COUNT(*) as nombre
FROM shops
WHERE devise_secondaire IS NOT NULL
  AND capital_cash_devise2 IS NULL
  AND capital_airtel_money_devise2 IS NULL
  AND capital_mpesa_devise2 IS NULL
  AND capital_orange_money_devise2 IS NULL;

-- ============================================================================
-- DÉPANNAGE
-- ============================================================================

-- Problème : Taux de change manquants
-- Solution : Réinsérer les taux par défaut
DELETE FROM taux WHERE devise_source IN ('USD', 'CDF') AND devise_cible IN ('CDF', 'UGX');
SOURCE c:/laragon1/www/UCASHV01/server/database/migration_multidevises.sql;

-- Problème : Colonnes multi-devises manquantes dans shops
-- Solution : Réexécuter la migration
ALTER TABLE shops 
ADD COLUMN IF NOT EXISTS devise_principale VARCHAR(10) DEFAULT 'USD' NOT NULL,
ADD COLUMN IF NOT EXISTS devise_secondaire VARCHAR(10) DEFAULT NULL;

-- Problème : Colonne devise manquante dans operations
-- Solution :
ALTER TABLE operations 
ADD COLUMN IF NOT EXISTS devise VARCHAR(10) DEFAULT 'USD' NOT NULL;
UPDATE operations SET devise = 'USD' WHERE devise IS NULL;

-- ============================================================================
-- FIN DU GUIDE
-- ============================================================================

SELECT '✓ Guide d\'installation et migration UCASH v2.0 chargé avec succès!' as message;
