-- Increase VARCHAR lengths for account IDs and referrer IDs
-- Some addresses/IDs can be longer than 42 characters

-- Update referral_points table
ALTER TABLE referral_points ALTER COLUMN account_id TYPE VARCHAR(100);

-- Update referral_relationships table
ALTER TABLE referral_relationships ALTER COLUMN referrer_id TYPE VARCHAR(100);
ALTER TABLE referral_relationships ALTER COLUMN referred_id TYPE VARCHAR(100);

-- Update position_snapshots table
ALTER TABLE position_snapshots ALTER COLUMN account_id TYPE VARCHAR(100);
ALTER TABLE position_snapshots ALTER COLUMN position_id TYPE VARCHAR(100); 