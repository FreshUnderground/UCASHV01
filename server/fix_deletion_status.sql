-- Script SQL pour corriger le statut de la demande de suppression
-- Exécuter dans phpMyAdmin ou votre client MySQL

-- Corriger la demande avec statut vide
UPDATE deletion_requests 
SET statut = 'admin_validee' 
WHERE code_ops = '251211224943822' AND statut = '';

-- Vérifier la correction
SELECT code_ops, statut, validated_by_admin_name, validation_admin_date
FROM deletion_requests 
WHERE code_ops = '251211224943822';
