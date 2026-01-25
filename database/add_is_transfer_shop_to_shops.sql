-- ===============================================
-- Ajouter le champ is_transfer_shop à la table shops
-- ===============================================
-- 
-- OBJECTIF:
-- Identifier explicitement quel shop sert les transferts par défaut
-- (précédemment identifié par le nom "KAMPALA")
--
-- LOGIQUE MÉTIER:
-- - Shop Principal (is_principal=1): Gère tous les flots (ex: Durba)
-- - Shop de Transfert (is_transfer_shop=1): Sert les transferts par défaut (ex: Kampala)
-- - Shops Normaux: is_principal=0 ET is_transfer_shop=0 (ex: C, D, E, F)
--
-- CONTRAINTE:
-- Un seul shop peut être marqué comme "transfer shop" à la fois
-- ===============================================

-- Ajouter la colonne is_transfer_shop
ALTER TABLE shops 
ADD COLUMN is_transfer_shop TINYINT(1) DEFAULT 0 
COMMENT 'Shop de transfert/service qui sert les transferts par défaut (1=Oui, 0=Non)';

-- Créer un index pour optimisation
CREATE INDEX idx_is_transfer_shop ON shops(is_transfer_shop);

-- Marquer automatiquement le shop "KAMPALA" existant comme transfer shop
UPDATE shops 
SET is_transfer_shop = 1 
WHERE UPPER(designation) LIKE '%KAMPALA%' 
AND is_transfer_shop = 0;

-- Vérification: Afficher les shops avec leurs types
SELECT 
    id,
    designation,
    localisation,
    CASE 
        WHEN is_principal = 1 THEN '🏦 PRINCIPAL'
        WHEN is_transfer_shop = 1 THEN '🔄 TRANSFERT'
        ELSE '📍 NORMAL'
    END as type_shop,
    is_principal,
    is_transfer_shop,
    capital_actuel
FROM shops
ORDER BY is_principal DESC, is_transfer_shop DESC, designation;

-- ===============================================
-- NOTES IMPORTANTES:
-- 
-- 1. Migration des données existantes:
--    Les shops avec "KAMPALA" dans le nom seront automatiquement
--    marqués comme transfer shops
--
-- 2. Contrainte métier (à implémenter dans l'application):
--    - Vérifier qu'il n'y a qu'un seul transfer shop actif
--    - Alerter si aucun transfer shop n'est configuré
--
-- 3. Rollback si nécessaire:
--    ALTER TABLE shops DROP COLUMN is_transfer_shop;
-- ===============================================
