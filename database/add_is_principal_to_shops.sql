-- ===============================================
-- Ajout du champ 'is_principal' à la table shops
-- Permet de distinguer le shop principal (siège/central) des shops secondaires
-- ===============================================

-- 1. Ajouter la colonne is_principal
ALTER TABLE shops 
ADD COLUMN is_principal TINYINT(1) DEFAULT 0 
COMMENT 'Shop principal (siège/central): 1=Oui, 0=Non';

-- 2. Créer un index pour optimiser les requêtes
CREATE INDEX idx_shops_is_principal ON shops(is_principal);

-- 3. Afficher la structure mise à jour
DESCRIBE shops;

-- ===============================================
-- REMARQUES IMPORTANTES
-- ===============================================
-- 
-- is_principal = 1 : Shop Principal (Siège/Central)
--   - C'est le shop de référence
--   - Généralement le premier shop créé
--   - Peut servir pour des rapports consolidés
--
-- is_principal = 0 : Shop Secondaire (Agence/Succursale)
--   - Shops classiques
--   - Valeur par défaut
--
-- UTILISATION:
--   - Lors de la création d'un shop, spécifier is_principal = 1 si c'est le siège
--   - Rechercher le shop principal: SELECT * FROM shops WHERE is_principal = 1
--   - Compter les shops secondaires: SELECT COUNT(*) FROM shops WHERE is_principal = 0
--
-- ===============================================
