-- Ajouter colonne pour stocker l'historique des paiements en JSON
-- Cette colonne permet de gérer les paiements multiples pour un même salaire

ALTER TABLE salaires 
ADD COLUMN IF NOT EXISTS historique_paiements_json TEXT NULL
COMMENT 'Historique des paiements en JSON - permet de tracker tous les versements pour un même salaire';

-- Exemple de structure JSON stockée:
-- [
--   {
--     "datePaiement": "2024-12-15T10:30:00",
--     "montant": 300.00,
--     "modePaiement": "Especes",
--     "agentPaiement": "Admin",
--     "notes": "Premier versement partiel"
--   },
--   {
--     "datePaiement": "2024-12-20T14:00:00",
--     "montant": 200.00,
--     "modePaiement": "Mobile Money",
--     "agentPaiement": "Admin",
--     "notes": "Solde restant"
--   }
-- ]
