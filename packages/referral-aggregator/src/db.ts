import { Kysely, PostgresDialect } from 'kysely'
import { Pool } from 'pg'
import { ConfigService } from './config'
import { Database } from './database/types'
import { KyselyMigrator } from './migrations/kysely-migrator'
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
  protected db: Kysely<Database>
  public config: ConfigService

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || '127.0.0.1',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'referral_points',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    })

    // Initialize Kysely with PostgreSQL dialect
    this.db = new Kysely<Database>({
      dialect: new PostgresDialect({
        pool: this.pool,
      }),
    })

    this.config = new ConfigService(this.db)
  }

  async migrate(): Promise<void> {
    const migrator = new KyselyMigrator(this.pool)
    await migrator.runMigrations()
  }

  // Enhanced points calculation with point distributions using raw SQL for complex operations
  async recordPointDistribution(
    accountId: string,
    referrerId: string,
    pointsAwarded: number,
    totalDepositsUsd: number,
    activeReferredUsers: number,
    periodStart: Date,
    periodEnd: Date,
  ): Promise<void> {
    const calculationTimestamp = new Date()

    const client = await this.pool.connect()
    try {
      await client.query('BEGIN')

      // Insert point distribution record
      await client.query(
        `
        INSERT INTO point_distributions (
          account_id, referrer_id, points_awarded, total_deposits_usd, 
          active_referred_users, calculation_timestamp, period_start, period_end
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (account_id, calculation_timestamp) DO UPDATE
        SET points_awarded = $3,
            total_deposits_usd = $4,
            active_referred_users = $5,
            period_start = $7,
            period_end = $8
      `,
        [
          accountId,
          referrerId,
          pointsAwarded,
          totalDepositsUsd,
          activeReferredUsers,
          calculationTimestamp,
          periodStart,
          periodEnd,
        ],
      )

      // Update referral_points summary
      await client.query(
        `
        INSERT INTO referral_points (
          account_id, points, total_deposits_usd, active_referred_users,
          last_calculation_timestamp, total_point_distributions
        )
        VALUES ($1, $2, $3, $4, $5, $2)
        ON CONFLICT (account_id) DO UPDATE
        SET points = referral_points.points + $2,
            total_deposits_usd = $3,
            active_referred_users = $4,
            last_calculation_timestamp = $5,
            total_point_distributions = referral_points.total_point_distributions + $2,
            last_updated = NOW()
      `,
        [accountId, pointsAwarded, totalDepositsUsd, activeReferredUsers, calculationTimestamp],
      )

      await client.query('COMMIT')
    } catch (error) {
      await client.query('ROLLBACK')
      throw error
    } finally {
      client.release()
    }
  }

  // User activity status management using Kysely
  async updateUserActivityStatus(
    accountId: string,
    totalDepositsUsd: number,
    lastDepositTimestamp?: Date,
  ): Promise<void> {
    const config = await this.config.getConfig()
    const isActive = totalDepositsUsd >= config.activeUserThresholdUsd

    await this.db
      .insertInto('user_activity_status')
      .values({
        account_id: accountId,
        total_deposits_usd: totalDepositsUsd.toString(),
        is_active: isActive,
        last_deposit_timestamp: lastDepositTimestamp || null,
      })
      .onConflict((oc) =>
        oc.column('account_id').doUpdateSet({
          total_deposits_usd: totalDepositsUsd.toString(),
          is_active: isActive,
          last_deposit_timestamp: lastDepositTimestamp || null,
        }),
      )
      .execute()
  }

  async getActiveReferredUsers(referrerId: string): Promise<string[]> {
    const result = await this.db
      .selectFrom('referral_relationships as rr')
      .innerJoin('user_activity_status as uas', 'rr.referred_id', 'uas.account_id')
      .select('rr.referred_id')
      .where('rr.referrer_id', '=', referrerId)
      .where('uas.is_active', '=', true)
      .distinct()
      .execute()

    return result.map((row) => row.referred_id)
  }

  async getUserActivityStatus(accountId: string): Promise<{
    accountId: string
    totalDepositsUsd: number
    isActive: boolean
    lastDepositTimestamp?: Date
    lastUpdated: Date
  } | null> {
    const result = await this.db
      .selectFrom('user_activity_status')
      .selectAll()
      .where('account_id', '=', accountId)
      .executeTakeFirst()

    if (!result) return null

    return {
      accountId: result.account_id,
      totalDepositsUsd: Number(result.total_deposits_usd),
      isActive: result.is_active,
      lastDepositTimestamp: result.last_deposit_timestamp
        ? new Date(result.last_deposit_timestamp as any)
        : undefined,
      lastUpdated: new Date(result.last_updated as any),
    }
  }

  async getLastCalculationTimestamp(): Promise<Date | null> {
    const result = await this.db
      .selectFrom('referral_points')
      .select((eb) => eb.fn.max('last_calculation_timestamp').as('last_calculation'))
      .where('last_calculation_timestamp', 'is not', null)
      .executeTakeFirst()

    return result?.last_calculation ? new Date(result.last_calculation as any) : null
  }

  // Complex queries using raw SQL for better control
  async getReferralRelationshipsWithActiveUsers(fromTimestamp?: Date): Promise<
    Array<{
      referrerId: string
      referredUsers: Array<{
        referredId: string
        chain: Chain
        referralTimestamp: Date
        totalDepositsUsd: number
        isActive: boolean
      }>
    }>
  > {
    let query = `
      SELECT 
        rr.referrer_id,
        rr.referred_id,
        rr.chain,
        rr.referral_timestamp,
        COALESCE(uas.total_deposits_usd::decimal, 0) as total_deposits_usd,
        COALESCE(uas.is_active, false) as is_active
      FROM referral_relationships rr
      LEFT JOIN user_activity_status uas ON rr.referred_id = uas.account_id
    `

    const params: any[] = []
    if (fromTimestamp) {
      query += ` WHERE rr.referral_timestamp >= $1`
      params.push(fromTimestamp)
    }

    query += ` ORDER BY rr.referrer_id, rr.referred_id`

    const result = await this.pool.query(query, params)

    // Group by referrer
    const grouped: { [referrerId: string]: any } = {}

    for (const row of result.rows) {
      if (!grouped[row.referrer_id]) {
        grouped[row.referrer_id] = {
          referrerId: row.referrer_id,
          referredUsers: [],
        }
      }

      grouped[row.referrer_id].referredUsers.push({
        referredId: row.referred_id,
        chain: row.chain,
        referralTimestamp: row.referral_timestamp,
        totalDepositsUsd: Number(row.total_deposits_usd || 0),
        isActive: row.is_active || false,
      })
    }

    return Object.values(grouped)
  }

  async getPointDistributionsForPeriod(
    periodStart: Date,
    periodEnd: Date,
  ): Promise<
    Array<{
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
    }>
  > {
    const result = await this.db
      .selectFrom('point_distributions')
      .selectAll()
      .where('period_start', '>=', periodStart)
      .where('period_end', '<=', periodEnd)
      .orderBy('calculation_timestamp', 'desc')
      .execute()

    return result.map((row) => ({
      id: row.id,
      accountId: row.account_id,
      referrerId: row.referrer_id,
      pointsAwarded: Number(row.points_awarded),
      totalDepositsUsd: Number(row.total_deposits_usd),
      activeReferredUsers: row.active_referred_users,
      calculationTimestamp: new Date(row.calculation_timestamp as any),
      periodStart: new Date(row.period_start as any),
      periodEnd: new Date(row.period_end as any),
      createdAt: new Date(row.created_at as any),
    }))
  }

  // Legacy methods for compatibility
  async upsertReferralPoints(
    accountId: string,
    points: number,
    totalDepositsUsd: number,
    activeReferredUsers: number,
  ): Promise<void> {
    await this.pool.query(
      `
      INSERT INTO referral_points (account_id, points, total_deposits_usd, active_referred_users)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (account_id) DO UPDATE
      SET points = $2,
          total_deposits_usd = $3,
          active_referred_users = $4,
          last_updated = NOW()
    `,
      [accountId, points, totalDepositsUsd, activeReferredUsers],
    )
  }

  async upsertReferralRelationship(
    referrerId: string,
    referredId: string,
    chain: Chain,
    referralTimestamp: Date,
  ): Promise<void> {
    await this.db
      .insertInto('referral_relationships')
      .values({
        referrer_id: referrerId,
        referred_id: referredId,
        chain,
        referral_timestamp: referralTimestamp,
      })
      .onConflict((oc) => oc.columns(['referrer_id', 'referred_id', 'chain']).doNothing())
      .execute()
  }

  async savePositionSnapshot(
    accountId: string,
    chain: Chain,
    positionId: string,
    depositAmountUsd: number,
    createdTimestamp: Date,
    referralTimestamp?: Date,
  ): Promise<void> {
    await this.pool.query(
      `
      INSERT INTO position_snapshots (
        account_id, chain, position_id, deposit_amount_usd,
        created_timestamp, referral_timestamp
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (account_id, chain, position_id) DO UPDATE
      SET deposit_amount_usd = $4,
          created_timestamp = $5,
          referral_timestamp = $6,
          snapshot_timestamp = NOW()
    `,
      [accountId, chain, positionId, depositAmountUsd, createdTimestamp, referralTimestamp],
    )

    // Update user activity status when saving position snapshot
    await this.updateUserActivityStatus(accountId, depositAmountUsd, createdTimestamp)
  }

  async getReferralPoints(accountId: string): Promise<{
    points: number
    totalDepositsUsd: number
    activeReferredUsers: number
    lastUpdated: Date
  } | null> {
    const result = await this.db
      .selectFrom('referral_points')
      .select(['points', 'total_deposits_usd', 'active_referred_users', 'last_updated'])
      .where('account_id', '=', accountId)
      .executeTakeFirst()

    if (!result) return null

    return {
      points: Number(result.points),
      totalDepositsUsd: Number(result.total_deposits_usd),
      activeReferredUsers: result.active_referred_users,
      lastUpdated: new Date(result.last_updated as any),
    }
  }

  async getReferredUsers(accountId: string): Promise<
    {
      referredId: string
      chain: Chain
      referralTimestamp: Date
    }[]
  > {
    const result = await this.db
      .selectFrom('referral_relationships')
      .select(['referred_id', 'chain', 'referral_timestamp'])
      .where('referrer_id', '=', accountId)
      .execute()

    return result.map((row) => ({
      referredId: row.referred_id,
      chain: row.chain,
      referralTimestamp: new Date(row.referral_timestamp as any),
    }))
  }

  async getPositionSnapshots(
    accountId: string,
    fromTimestamp: Date,
  ): Promise<
    {
      chain: Chain
      positionId: string
      depositAmountUsd: number
      createdTimestamp: Date
      referralTimestamp?: Date
      snapshotTimestamp: Date
    }[]
  > {
    const result = await this.pool.query(
      `
      SELECT chain, position_id, deposit_amount_usd, created_timestamp,
             referral_timestamp, snapshot_timestamp
      FROM position_snapshots
      WHERE account_id = $1 AND snapshot_timestamp >= $2
      ORDER BY snapshot_timestamp DESC
    `,
      [accountId, fromTimestamp],
    )

    return result.rows.map((row: PositionSnapshotRow) => ({
      chain: row.chain,
      positionId: row.position_id,
      depositAmountUsd: row.deposit_amount_usd,
      createdTimestamp: row.created_timestamp,
      referralTimestamp: row.referral_timestamp,
      snapshotTimestamp: row.snapshot_timestamp,
    }))
  }

  async close(): Promise<void> {
    await this.db.destroy()
  }

  async hasAnyData(): Promise<boolean> {
    try {
      const result = await this.pool.query('SELECT COUNT(*) as count FROM referral_points LIMIT 1')
      return parseInt(result.rows[0].count) > 0
    } catch (error) {
      console.error('Error checking if database has data:', error)
      return false
    }
  }

  async getAllReferrerAccounts(): Promise<string[]> {
    const result = await this.db
      .selectFrom('referral_relationships')
      .select('referrer_id')
      .distinct()
      .execute()

    return result.map((row) => row.referrer_id)
  }

  async getAllAccountsWithPoints(): Promise<
    Array<{
      accountId: string
      points: number
      totalDepositsUsd: number
      activeReferredUsers: number
      lastUpdated: Date
    }>
  > {
    const result = await this.db
      .selectFrom('referral_points')
      .selectAll()
      .orderBy('points', 'desc')
      .execute()

    return result.map((row) => ({
      accountId: row.account_id,
      points: Number(row.points),
      totalDepositsUsd: Number(row.total_deposits_usd),
      activeReferredUsers: row.active_referred_users,
      lastUpdated: new Date(row.last_updated as any),
    }))
  }

  // Direct database access for complex queries
  get rawDb() {
    return this.pool
  }
}
