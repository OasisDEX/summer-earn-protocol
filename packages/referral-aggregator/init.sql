-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum for chain types
CREATE TYPE chain_type AS ENUM ('Ethereum', 'Polygon', 'Arbitrum', 'Base');

-- Create table for referral points
CREATE TABLE referral_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id TEXT NOT NULL,
    points DECIMAL NOT NULL DEFAULT 0,
    total_deposits_usd DECIMAL NOT NULL DEFAULT 0,
    active_referred_users INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(account_id)
);

-- Create table for referral relationships
CREATE TABLE referral_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id TEXT NOT NULL,
    referred_id TEXT NOT NULL,
    chain chain_type NOT NULL,
    referral_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(referrer_id, referred_id, chain)
);

-- Create table for position snapshots
CREATE TABLE position_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id TEXT NOT NULL,
    chain chain_type NOT NULL,
    position_id TEXT NOT NULL,
    deposit_amount_usd DECIMAL NOT NULL,
    created_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    referral_timestamp TIMESTAMP WITH TIME ZONE,
    snapshot_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(account_id, chain, position_id, snapshot_timestamp)
);

-- Create indexes
CREATE INDEX idx_referral_points_account_id ON referral_points(account_id);
CREATE INDEX idx_referral_relationships_referrer_id ON referral_relationships(referrer_id);
CREATE INDEX idx_referral_relationships_referred_id ON referral_relationships(referred_id);
CREATE INDEX idx_position_snapshots_account_id ON position_snapshots(account_id);
CREATE INDEX idx_position_snapshots_snapshot_timestamp ON position_snapshots(snapshot_timestamp);

-- Create function to calculate referral points
CREATE OR REPLACE FUNCTION calculate_referral_points(
    total_deposits DECIMAL,
    active_referred_users INTEGER
) RETURNS DECIMAL AS $$
BEGIN
    RETURN total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE; 