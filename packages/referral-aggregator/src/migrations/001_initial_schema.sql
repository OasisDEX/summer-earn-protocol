-- Create referral_points table
CREATE TABLE IF NOT EXISTS referral_points (
    account_id VARCHAR(42) PRIMARY KEY,
    points DECIMAL(20, 8) NOT NULL DEFAULT 0,
    total_deposits_usd DECIMAL(20, 8) NOT NULL DEFAULT 0,
    active_referred_users INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create referral_relationships table
CREATE TABLE IF NOT EXISTS referral_relationships (
    referrer_id VARCHAR(42) NOT NULL,
    referred_id VARCHAR(42) NOT NULL,
    chain VARCHAR(20) NOT NULL,
    referral_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (referrer_id, referred_id, chain)
);

-- Create position_snapshots table
CREATE TABLE IF NOT EXISTS position_snapshots (
    id SERIAL PRIMARY KEY,
    account_id VARCHAR(42) NOT NULL,
    chain VARCHAR(20) NOT NULL,
    position_id VARCHAR(66) NOT NULL,
    deposit_amount_usd DECIMAL(20, 8) NOT NULL,
    created_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    referral_timestamp TIMESTAMP WITH TIME ZONE,
    snapshot_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(account_id, chain, position_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_referral_points_account_id ON referral_points(account_id);
CREATE INDEX IF NOT EXISTS idx_referral_relationships_referrer_id ON referral_relationships(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_relationships_referred_id ON referral_relationships(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_relationships_chain ON referral_relationships(chain);
CREATE INDEX IF NOT EXISTS idx_referral_relationships_timestamp ON referral_relationships(referral_timestamp);
CREATE INDEX IF NOT EXISTS idx_position_snapshots_account_id ON position_snapshots(account_id);
CREATE INDEX IF NOT EXISTS idx_position_snapshots_chain ON position_snapshots(chain);
CREATE INDEX IF NOT EXISTS idx_position_snapshots_created_timestamp ON position_snapshots(created_timestamp);
CREATE INDEX IF NOT EXISTS idx_position_snapshots_snapshot_timestamp ON position_snapshots(snapshot_timestamp);

-- Create migrations table to track applied migrations
CREATE TABLE IF NOT EXISTS migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
); 