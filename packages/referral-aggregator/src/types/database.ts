/**
 * Database schema type definitions matching the new structure
 */

export interface ReferralCode {
  id: string // referral_id
  custom_code?: string | null // optional custom string
  points_per_day: number
  total_tvl: number
  total_active_users: number
  total_fees: number
  total_current_fees: number
  fees_per_day: number
  created_at: Date
  updated_at: Date
}

export interface User {
  id: string // user address
  referral_id?: string | null // this user's referral code (FK to referral_codes.id)
  referrer_id?: string | null // who referred this user (FK to referral_codes.id)
  referral_chain?: string | null // chain where user was referred
  referral_timestamp?: Date | null // when they were referred
  created_at: Date
  updated_at: Date
}

export interface Position {
  id: string // position id from subgraph
  user_id: string // FK to users.id
  chain: string
  // Virtual fields from latest snapshot
  amount_deposited: number
  total_fees_earned: number
  current_fees_earned: number
  fees_per_day: number
  created_at: Date
  updated_at: Date
}

export interface PositionSnapshot {
  id: number
  position_id: string // FK to positions.id
  chain: string // FK to positions.chain (composite key)
  deposit_amount_usd: number
  total_fees_earned: number
  current_fees_earned: number
  fees_per_day: number
  snapshot_timestamp: Date
  created_at: Date
}

export interface PointDistribution {
  id: number
  referral_id: string // FK to referral_codes.id
  points_awarded: number
  total_deposits_usd: number
  active_referred_users: number
  calculation_timestamp: Date
  period_start: Date
  period_end: Date
  created_at: Date
}

export interface UserActivityStatus {
  user_id: string // PK and FK to users.id
  total_deposits_usd: number
  is_active: boolean
  last_deposit_timestamp?: Date | null
  last_updated: Date
}

export interface PointsConfig {
  id: number
  key: string
  value: string
  description?: string | null
  created_at: Date
  updated_at: Date
}

// Helper types for queries
export interface ReferralRelationship {
  referrerId: string
  referredUsers: Array<{
    userId: string
    chain: string
    referralTimestamp: Date | null
    totalDepositsUsd: number
    isActive: boolean
  }>
}

export interface UserWithPositions {
  user: User
  positions: Position[]
}

export interface ReferrerWithAllPositions {
  referrerId: string
  referralCode: ReferralCode
  directPositions: Position[] // referrer's own positions
  referredUsersPositions: Array<{
    userId: string
    positions: Position[]
  }>
} 