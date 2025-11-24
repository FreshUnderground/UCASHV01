-- Script pour permettre l'insertion d'IDs personnalisés dans cloture_caisse
-- Cela permet aux clôtures créées localement d'utiliser leurs IDs générés par timestamp
-- tout en maintenant l'AUTO_INCREMENT pour les IDs générés par le serveur

-- Modifier l'AUTO_INCREMENT pour éviter les conflits avec les IDs existants
-- Les IDs locaux utilisent des timestamps (ex: 1732320000000)
-- Donc on garde l'AUTO_INCREMENT en dessous de ce seuil
ALTER TABLE cloture_caisse AUTO_INCREMENT = 1000;

-- Ajouter un commentaire pour documenter la stratégie d'ID
ALTER TABLE cloture_caisse COMMENT = 'ID Strategy: Timestamp IDs pour clôtures locales, Auto-increment pour serveur';

-- Vérifier les changements
SHOW CREATE TABLE cloture_caisse;

-- Afficher la valeur AUTO_INCREMENT actuelle
SELECT AUTO_INCREMENT 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'cloture_caisse';
