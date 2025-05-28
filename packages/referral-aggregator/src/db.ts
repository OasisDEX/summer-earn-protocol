import { Pool } from 'pg'
import { Chain } from './types'

interface ReferralRelationshipRow {
  referred_id: string
  chain: Chain
  referral_timestamp: Date
}

interface PositionSnapshotRow {
  chain: Chain
  position_id: string
  deposit_amount_usd: number
  created_timestamp: Date
  referral_timestamp?: Date
  snapshot_timestamp: Date
}

export class DatabaseService {
  protected pool: Pool

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'referral_points',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres'
    })
  }

  async upsertReferralPoints(
    accountId: string,
    points: number,
    totalDepositsUsd: number,
    activeReferredUsers: number
  ): Promise<void> {
    const query = `
      INSERT INTO referral_points (account_id, points, total_deposits_usd, active_referred_users)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (account_id) DO UPDATE
      SET points = $2,
          total_deposits_usd = $3,
          active_referred_users = $4,
          last_updated = NOW()
    `
    await this.pool.query(query, [accountId, points, totalDepositsUsd, activeReferredUsers])
  }

  async upsertReferralRelationship(
    referrerId: string,
    referredId: string,
    chain: Chain,
    referralTimestamp: Date
  ): Promise<void> {
    const query = `
      INSERT INTO referral_relationships (referrer_id, referred_id, chain, referral_timestamp)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (referrer_id, referred_id, chain) DO NOTHING
    `
    await this.pool.query(query, [referrerId, referredId, chain, referralTimestamp])
  }

  async savePositionSnapshot(
    accountId: string,
    chain: Chain,
    positionId: string,
    depositAmountUsd: number,
    createdTimestamp: Date,
    referralTimestamp?: Date
  ): Promise<void> {
    const query = `
      INSERT INTO position_snapshots (
        account_id, chain, position_id, deposit_amount_usd,
        created_timestamp, referral_timestamp
      )
      VALUES ($1, $2, $3, $4, $5, $6)
    `
    await this.pool.query(query, [
      accountId,
      chain,
      positionId,
      depositAmountUsd,
      createdTimestamp,
      referralTimestamp
    ])
  }

  async getReferralPoints(accountId: string): Promise<{
    points: number
    totalDepositsUsd: number
    activeReferredUsers: number
    lastUpdated: Date
  } | null> {
    const query = `
      SELECT points, total_deposits_usd, active_referred_users, last_updated
      FROM referral_points
      WHERE account_id = $1
    `
    const result = await this.pool.query(query, [accountId])
    return result.rows[0] || null
  }

  async getReferredUsers(accountId: string): Promise<{
    referredId: string
    chain: Chain
    referralTimestamp: Date
  }[]> {
    const query = `
      SELECT referred_id, chain, referral_timestamp
      FROM referral_relationships
      WHERE referrer_id = $1
    `
    const result = await this.pool.query(query, [accountId])
    return result.rows.map((row: ReferralRelationshipRow) => ({
      referredId: row.referred_id,
      chain: row.chain,
      referralTimestamp: row.referral_timestamp
    }))
  }

  async getPositionSnapshots(
    accountId: string,
    fromTimestamp: Date
  ): Promise<{
    chain: Chain
    positionId: string
    depositAmountUsd: number
    createdTimestamp: Date
    referralTimestamp?: Date
    snapshotTimestamp: Date
  }[]> {
    const query = `
      SELECT chain, position_id, deposit_amount_usd, created_timestamp,
             referral_timestamp, snapshot_timestamp
      FROM position_snapshots
      WHERE account_id = $1 AND snapshot_timestamp >= $2
      ORDER BY snapshot_timestamp DESC
    `
    const result = await this.pool.query(query, [accountId, fromTimestamp])
    return result.rows.map((row: PositionSnapshotRow) => ({
      chain: row.chain,
      positionId: row.position_id,
      depositAmountUsd: row.deposit_amount_usd,
      createdTimestamp: row.created_timestamp,
      referralTimestamp: row.referral_timestamp,
      snapshotTimestamp: row.snapshot_timestamp
    }))
  }

  async close(): Promise<void> {
    await this.pool.end()
  }
} 