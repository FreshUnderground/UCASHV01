-- Script to update shops table to support negative local IDs
-- This allows local shops to be inserted with their negative IDs
-- while maintaining MySQL's auto-increment for server-generated IDs

-- This script should be run once to update the existing table structure

-- The approach is to keep AUTO_INCREMENT but allow manual ID insertion
-- MySQL will automatically adjust AUTO_INCREMENT value to avoid conflicts

-- Ensure AUTO_INCREMENT starts at a value that won't conflict with existing negative IDs
-- This is important for new installations or when there are no existing shops
ALTER TABLE shops AUTO_INCREMENT = 1000;

-- Add a comment to document the ID strategy
ALTER TABLE shops COMMENT = 'ID Strategy: Negative IDs for local shops, Positive IDs for server shops';

-- Verify the changes
SHOW CREATE TABLE shops;

-- Show current AUTO_INCREMENT value
SELECT AUTO_INCREMENT 
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
AND TABLE_NAME = 'shops';