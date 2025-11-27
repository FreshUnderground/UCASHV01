-- Ajouter les colonnes shop_source_designation et shop_destination_designation à la table flots
-- Ces colonnes stockent les noms des shops pour éviter les jointures lors de l'affichage

ALTER TABLE `flots`
ADD COLUMN `shop_source_designation` VARCHAR(255) DEFAULT NULL AFTER `shop_source_id`,
ADD COLUMN `shop_destination_designation` VARCHAR(255) DEFAULT NULL AFTER `shop_destination_id`;

-- Créer des index pour améliorer les performances de recherche
CREATE INDEX `idx_shop_source_designation` ON `flots` (`shop_source_designation`);
CREATE INDEX `idx_shop_destination_designation` ON `flots` (`shop_destination_designation`);

-- Mettre à jour les enregistrements existants avec les désignations des shops
UPDATE `flots` f
INNER JOIN `shops` s_source ON f.shop_source_id = s_source.id
SET f.shop_source_designation = s_source.designation;

UPDATE `flots` f
INNER JOIN `shops` s_dest ON f.shop_destination_id = s_dest.id
SET f.shop_destination_designation = s_dest.designation;
