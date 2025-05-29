import { ColumnType } from 'kysely'
import { Chain } from '../types'

// Helper types for Kysely
export type Generated<T> = ColumnType<T, T | undefined, never>
export type Timestamp = ColumnType<Date, Date | string, Date | string>

// Database table interfaces
export interface ReferralPointsTable {
  account_id: string
  points: ColumnType<string, string | number, string | number>
  total_deposits_usd: ColumnType<string, string | number, string | number>
  active_referred_users: number
  last_updated: Generated<Timestamp>
  created_at: Generated<Timestamp>
  last_calculation_timestamp: Timestamp | null
  total_point_distributions: ColumnType<string, string | number | undefined, string | number>
}

export interface ReferralRelationshipsTable {
  referrer_id: string
  referred_id: string
  chain: Chain
  referral_timestamp: Timestamp
  created_at: Generated<Timestamp>
}

export interface PositionSnapshotsTable {
  id: Generated<number>
  account_id: string
  chain: Chain
  position_id: string
  deposit_amount_usd: ColumnType<string, string | number, string | number>
  created_timestamp: Timestamp
  referral_timestamp: Timestamp | null
  snapshot_timestamp: Generated<Timestamp>
}

export interface PointDistributionsTable {
  id: Generated<number>
  account_id: string
  referrer_id: string
  points_awarded: ColumnType<string, string | number, string | number>
  total_deposits_usd: ColumnType<string, string | number, string | number>
  active_referred_users: number
  calculation_timestamp: Timestamp
  period_start: Timestamp
  period_end: Timestamp
  created_at: Generated<Timestamp>
}

export interface UserActivityStatusTable {
  account_id: string
  total_deposits_usd: ColumnType<string, string | number, string | number>
  is_active: boolean
  last_deposit_timestamp: Timestamp | null
  last_updated: Generated<Timestamp>
}

export interface PointsConfigTable {
  id: Generated<number>
  key: string
  value: string
  description: string | null
  created_at: Generated<Timestamp>
  updated_at: Timestamp
}

export interface MigrationsTable {
  id: Generated<number>
  filename: string
  applied_at: Generated<Timestamp>
}

// Main database interface
export interface Database {
  referral_points: ReferralPointsTable
  referral_relationships: ReferralRelationshipsTable
  position_snapshots: PositionSnapshotsTable
  point_distributions: PointDistributionsTable
  user_activity_status: UserActivityStatusTable
  points_config: PointsConfigTable
  migrations: MigrationsTable
}

// Helper types for selecting and inserting
export type ReferralPoints = {
  accountId: string
  points: number
  totalDepositsUsd: number
  activeReferredUsers: number
  lastUpdated: Date
  createdAt: Date
  lastCalculationTimestamp?: Date
  totalPointDistributions: number
}

export type PointDistribution = {
  id: number
  accountId: string
  referrerId: string
  pointsAwarded: number
  totalDepositsUsd: number
  activeReferredUsers: number
  calculationTimestamp: Date
  periodStart: Date
  periodEnd: Date
  createdAt: Date
}

export type UserActivityStatus = {
  accountId: string
  totalDepositsUsd: number
  isActive: boolean
  lastDepositTimestamp?: Date
  lastUpdated: Date
}

export type ReferralRelationship = {
  referrerId: string
  referredId: string
  chain: Chain
  referralTimestamp: Date
  createdAt: Date
}
