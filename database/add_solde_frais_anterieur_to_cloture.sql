-- Migration pour ajouter le champ solde_frais_anterieur à la table cloture_caisse
-- Ce champ enregistre le solde FRAIS du shop au moment de la clôture
-- Il servira de "Frais Antérieur" pour le jour suivant

-- Ajouter la colonne solde_frais_anterieur
ALTER TABLE cloture_caisse
ADD COLUMN solde_frais_anterieur DECIMAL(15,2) NOT NULL DEFAULT 0.00 
COMMENT 'Solde du compte FRAIS au moment de la clôture (servira d''antérieur pour le jour suivant)'
AFTER date_cloture;

-- Vérifier la structure de la table
DESCRIBE cloture_caisse;

-- Afficher un message de confirmation
SELECT 'Migration réussie: solde_frais_anterieur ajouté à cloture_caisse' AS message;
