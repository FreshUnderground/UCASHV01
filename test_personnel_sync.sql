-- Script de test pour vérifier la synchronisation du personnel
-- À exécuter dans phpMyAdmin pour diagnostiquer les problèmes de sync

-- 1. Vérifier la structure de la table
DESCRIBE personnel;

-- 2. Compter les enregistrements
SELECT COUNT(*) as total_personnel FROM personnel;

-- 3. Vérifier les enregistrements non synchronisés
SELECT 
    matricule, 
    nom, 
    prenom, 
    is_synced, 
    synced_at, 
    last_modified_at 
FROM personnel 
WHERE is_synced = 0 OR is_synced IS NULL;

-- 4. Vérifier les enregistrements récents
SELECT 
    matricule, 
    nom, 
    prenom, 
    is_synced, 
    created_at,
    last_modified_at 
FROM personnel 
ORDER BY last_modified_at DESC 
LIMIT 10;

-- 5. Insérer un enregistrement de test pour vérifier la sync
INSERT INTO personnel (
    matricule, nom, prenom, telephone, poste, date_embauche, 
    salaire_base, is_synced, created_at, last_modified_at
) VALUES (
    'TEST001', 'Test', 'Sync', '+243999999999', 'Agent Test', 
    CURDATE(), 100.00, 0, NOW(), NOW()
);

-- 6. Vérifier que l'enregistrement de test a été créé
SELECT * FROM personnel WHERE matricule = 'TEST001';

-- 7. Statistiques de synchronisation
SELECT 
    is_synced,
    COUNT(*) as count,
    MIN(last_modified_at) as oldest,
    MAX(last_modified_at) as newest
FROM personnel 
GROUP BY is_synced;
