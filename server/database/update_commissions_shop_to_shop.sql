-- Migration script to update commissions table for shop-to-shop routing
-- This script adds source_shop_id and destination_shop_id columns to support route-specific commissions

-- Add new columns for source and destination shop IDs
ALTER TABLE `commissions` 
ADD COLUMN `source_shop_id` INT(11) DEFAULT NULL COMMENT 'Source shop ID for route-specific commissions',
ADD COLUMN `destination_shop_id` INT(11) DEFAULT NULL COMMENT 'Destination shop ID for route-specific commissions';

-- Add indexes for better performance
ALTER TABLE `commissions` 
ADD KEY `idx_source_shop` (`source_shop_id`),
ADD KEY `idx_destination_shop` (`destination_shop_id`);

-- Add foreign key constraints
ALTER TABLE `commissions` 
ADD CONSTRAINT `fk_commission_source_shop` FOREIGN KEY (`source_shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE,
ADD CONSTRAINT `fk_commission_destination_shop` FOREIGN KEY (`destination_shop_id`) REFERENCES `shops` (`id`) ON DELETE CASCADE;

-- Update existing records to maintain backward compatibility
-- Global commissions (where shop_id IS NULL) remain unchanged
-- Shop-specific commissions (where shop_id IS NOT NULL) become source_shop_id
UPDATE `commissions` 
SET `source_shop_id` = `shop_id` 
WHERE `shop_id` IS NOT NULL AND `source_shop_id` IS NULL;

-- Drop the old shop_id column since we're using source_shop_id and destination_shop_id
-- We'll keep it for now to maintain backward compatibility, but mark it as deprecated
-- ALTER TABLE `commissions` DROP COLUMN `shop_id`;

-- Create indexes for the new commission lookup patterns
CREATE INDEX `idx_source_dest_commission` ON `commissions` (`source_shop_id`, `destination_shop_id`, `type`);
CREATE INDEX `idx_source_commission` ON `commissions` (`source_shop_id`, `type`);