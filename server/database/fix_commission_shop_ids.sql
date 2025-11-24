-- Fix commission shop-to-shop IDs
-- The shop_source_id and shop_destination_id were swapped/incorrect

-- kindu→kpla (1.2%)
-- shop_source_id should be kindu (1763936982397), destination should be kpla (1)
UPDATE commissions 
SET shop_source_id = 1763936982397, 
    shop_destination_id = 1,
    is_synced = 0,
    last_modified_at = NOW(),
    last_modified_by = 'admin_fix'
WHERE id = 1763937774604;

-- kis→kpla (1.6%)
-- shop_source_id should be kis (3), destination should be kpla (1)
UPDATE commissions 
SET shop_source_id = 3, 
    shop_destination_id = 1,
    is_synced = 0,
    last_modified_at = NOW(),
    last_modified_by = 'admin_fix'
WHERE id = 1763938985017;

-- Durba→Kpla (1.5%)
-- shop_source_id should be Durba (4), destination should be kpla (1)
UPDATE commissions 
SET shop_source_id = 4, 
    shop_destination_id = 1,
    is_synced = 0,
    last_modified_at = NOW(),
    last_modified_by = 'admin_fix'
WHERE id = 1763938954216;

-- kinde→Durba (1.35%) - if it exists
UPDATE commissions 
SET shop_source_id = 1763936982397, 
    shop_destination_id = 4,
    is_synced = 0,
    last_modified_at = NOW(),
    last_modified_by = 'admin_fix'
WHERE id = 1763940885420;

-- Verify the changes
SELECT 
    id,
    type,
    taux,
    description,
    shop_source_id,
    shop_destination_id,
    is_synced,
    last_modified_at
FROM commissions
ORDER BY id;
