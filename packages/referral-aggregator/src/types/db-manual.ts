/**
 * Manual database type definitions for the new schema
 * Use this until kysely-codegen properly generates the types
 */

import { ColumnType, Generated } from 'kysely'

// Helper types
type Timestamp = ColumnType<Date, Date | string, Date | string>
type Decimal = ColumnType<string, string | number, string | number>
type Nullable<T> = T | null

// Table interfaces
export interface ReferralCodesTable {
  id: string
  custom_code: Nullable<string>
  points_per_day: Decimal
  total_tvl: Decimal
  total_active_users: number
  total_fees: Decimal
  total_current_fees: Decimal
  fees_per_day: Decimal
  created_at: Generated<Timestamp>
  updated_at: Generated<Timestamp>
}

export interface UsersTable {
  id: string
  referral_id: Nullable<string>
  referrer_id: Nullable<string>
  referral_chain: Nullable<string>
  referral_timestamp: Nullable<Timestamp>
  created_at: Generated<Timestamp>
  updated_at: Generated<Timestamp>
}

export interface PositionsTable {
  id: string
  user_id: string
  chain: string
  amount_deposited: Decimal
  total_fees_earned: Decimal
  current_fees_earned: Decimal
  fees_per_day: Decimal
  created_at: Generated<Timestamp>
  updated_at: Generated<Timestamp>
}

export interface PositionSnapshotsTable {
  id: Generated<number>
  position_id: string
  chain: string
  deposit_amount_usd: Decimal
  total_fees_earned: Decimal
  current_fees_earned: Decimal
  fees_per_day: Decimal
  snapshot_timestamp: Timestamp
  created_at: Generated<Timestamp>
}

export interface PointDistributionsTable {
  id: Generated<number>
  referral_id: string
  points_awarded: Decimal
  total_deposits_usd: Decimal
  active_referred_users: number
  calculation_timestamp: Timestamp
  period_start: Timestamp
  period_end: Timestamp
  created_at: Generated<Timestamp>
}

export interface UserActivityStatusTable {
  user_id: string
  total_deposits_usd: Decimal
  is_active: boolean
  last_deposit_timestamp: Nullable<Timestamp>
  last_updated: Generated<Timestamp>
}

export interface PointsConfigTable {
  id: Generated<number>
  key: string
  value: string
  description: Nullable<string>
  created_at: Generated<Timestamp>
  updated_at: Generated<Timestamp>
}

export interface MigrationsTable {
  id: Generated<number>
  filename: string
  applied_at: Generated<Timestamp>
}

// Complete database interface
export interface DB {
  referral_codes: ReferralCodesTable
  users: UsersTable
  positions: PositionsTable
  position_snapshots: PositionSnapshotsTable
  point_distributions: PointDistributionsTable
  user_activity_status: UserActivityStatusTable
  points_config: PointsConfigTable
  migrations: MigrationsTable
}
