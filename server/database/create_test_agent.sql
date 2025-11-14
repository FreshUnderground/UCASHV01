-- Script pour créer un agent de test dans MySQL
-- Exécuter ce script si aucun agent n'existe

-- Vérifier d'abord si le shop existe
SELECT id, designation FROM shops ORDER BY id LIMIT 5;

-- Créer un agent test (remplacez shop_id=1 par un ID de shop existant)
INSERT INTO agents (
    username, 
    password, 
    nom, 
    shop_id, 
    role, 
    is_active, 
    created_at, 
    last_modified_at, 
    last_modified_by,
    is_synced,
    synced_at
)
VALUES (
    'agent1',           -- Username
    'password123',      -- Password (en production, hasher!)
    'Agent Test',       -- Nom
    1,                  -- Shop ID (assurez-vous que ce shop existe)
    'AGENT',            -- Role
    1,                  -- Active (true)
    NOW(),              -- Created at
    NOW(),              -- Last modified at
    'admin',            -- Last modified by
    1,                  -- Is synced
    NOW()               -- Synced at
);

-- Vérifier que l'agent a été créé
SELECT id, username, nom, shop_id, role, is_active, created_at 
FROM agents 
WHERE username = 'agent1';
