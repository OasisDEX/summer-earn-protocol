import { Kysely, PostgresDialect, sql } from 'kysely'
import { Pool } from 'pg'
import { ConfigService } from './config'
import { KyselyMigrator } from './migrations/kysely-migrator'
import { Chain } from './types'
import { DB } from 'kysely-codegen';

interface UserRow {
  id: string
  chain: Chain
  referrer_id: string | null
  referral_timestamp: Date | null
}

interface ReferralUserRow extends UserRow {
  total_deposits_usd: number
  is_active: boolean
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
  protected db: Kysely<DB>
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
    this.db = new Kysely<DB>({
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

    await this.db.transaction().execute(async (trx) => {
      // Insert point distribution record
      await trx
        .insertInto('point_distributions')
        .values({
          account_id: accountId,
          referrer_id: referrerId,
          points_awarded: pointsAwarded,
          total_deposits_usd: totalDepositsUsd,
          active_referred_users: activeReferredUsers,
          calculation_timestamp: calculationTimestamp,
          period_start: periodStart,
          period_end: periodEnd,
        })
        .onConflict((oc) =>
          oc.columns(['account_id', 'calculation_timestamp']).doUpdateSet({
            points_awarded: pointsAwarded,
            total_deposits_usd: totalDepositsUsd,
            active_referred_users: activeReferredUsers,
            period_start: periodStart,
            period_end: periodEnd,
          }),
        )
        .execute()

      // Update referral_points summary
      await trx
        .insertInto('referral_points')
        .values({
          account_id: accountId,
          points: pointsAwarded,
          total_deposits_usd: totalDepositsUsd,
          active_referred_users: activeReferredUsers,
          last_calculation_timestamp: calculationTimestamp,
          total_point_distributions: pointsAwarded,
        })
        .onConflict((oc) =>
          oc.column('account_id').doUpdateSet({
            points: sql`referral_points.points + ${pointsAwarded}`,
            total_deposits_usd: sql`referral_points.total_deposits_usd + ${totalDepositsUsd}`,
            active_referred_users: sql`referral_points.active_referred_users + ${activeReferredUsers}`,
            last_calculation_timestamp: calculationTimestamp,
            total_point_distributions: sql`referral_points.total_point_distributions + ${pointsAwarded}`,
            last_updated: sql`NOW()`,
          }),
        )
        .execute()
    })
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

  // Users table methods (replacing referral_relationships)
  async upsertUser(
    userId: string,
    chain: Chain,
    referrerId: string | null = null,
    referralTimestamp: Date | null = null,
  ): Promise<void> {
    await this.db
      .insertInto('users')
      .values({
        id: userId,
        referral_chain: chain,
        referrer_id: referrerId,
        referral_timestamp: referralTimestamp,
      })
      .onConflict((oc) =>
        oc.columns(['id', 'referral_chain']).doUpdateSet({
          referrer_id: referrerId,
          referral_timestamp: referralTimestamp,
        }),
      )
      .execute()
  }

  // New method to store referred accounts (accounts that were referred)
  async storeReferredAccounts(
    accounts: Array<{
      referrerId: string | null
      referredId: string
      referredChain: Chain
      referralTimestamp: Date
    }>,
  ): Promise<void> {
    for (const account of accounts) {
      await this.upsertUser(
        account.referredId,
        account.referredChain,
        account.referrerId,
        account.referralTimestamp,
      )
    }
  }

  async getActiveReferredUsers(referrerId: string): Promise<string[]> {
    const result = await this.db
      .selectFrom('users as u')
      .innerJoin('user_activity_status as uas', 'u.id', 'uas.account_id')
      .select('u.id')
      .where('u.referrer_id', '=', referrerId)
      .where('uas.is_active', '=', true)
      .distinct()
      .execute()

    return result.map((row) => row.id)
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

  // Get referral relationships with active users using the new users table
  async getReferralRelationshipsWithActiveUsers(): Promise<
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
        u.referrer_id,
        u.id as referred_id,
        u.referral_chain,
        u.referral_timestamp,
        COALESCE(uas.total_deposits_usd::decimal, 0) as total_deposits_usd,
        COALESCE(uas.is_active, false) as is_active
      FROM users u
      LEFT JOIN user_activity_status uas ON u.id = uas.account_id
      WHERE u.referrer_id IS NOT NULL
      ORDER BY u.referrer_id, u.id
    `

    const result = await this.pool.query(query)

    // Group by referrer
    const grouped: { [referrerId: string]: any } = {}

    for (const row of result.rows) {
      // Skip rows where referrer_id is null
      if (!row.referrer_id) continue

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
        isActive: Number(row.total_deposits_usd > 1),
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

  // Custom referral codes methods
  async createCustomReferralCode(
    customCode: string,
    actualReferrerId: string,
    referrerAddress: string,
  ): Promise<void> {
    await this.db
      .insertInto('custom_referral_codes')
      .values({
        custom_code: customCode,
        actual_referrer_id: actualReferrerId,
        referrer_address: referrerAddress,
        is_active: true,
      })
      .execute()
  }

  async getCustomReferralCode(customCode: string): Promise<{
    actualReferrerId: string
    referrerAddress: string
    isActive: boolean
  } | null> {
    const result = await this.db
      .selectFrom('custom_referral_codes')
      .select(['actual_referrer_id', 'referrer_address', 'is_active'])
      .where('custom_code', '=', customCode)
      .where('is_active', '=', true)
      .executeTakeFirst()

    if (!result) return null

    return {
      actualReferrerId: result.actual_referrer_id,
      referrerAddress: result.referrer_address,
      isActive: result.is_active,
    }
  }

  async deactivateCustomReferralCode(customCode: string): Promise<void> {
    await this.db
      .updateTable('custom_referral_codes')
      .set({ is_active: false })
      .where('custom_code', '=', customCode)
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
    await this.db.transaction().execute(async (trx) => {
      await trx
        .insertInto('position_snapshots')
        .values({
          account_id: accountId,
          chain: chain,
          position_id: positionId,
          deposit_amount_usd: depositAmountUsd,
          created_timestamp: createdTimestamp,
          referral_timestamp: referralTimestamp,
          snapshot_timestamp: sql`NOW()`,
        })
        .onConflict((oc) =>
          oc.columns(['account_id', 'chain', 'position_id']).doUpdateSet({
            deposit_amount_usd: depositAmountUsd,
            created_timestamp: createdTimestamp,
            referral_timestamp: referralTimestamp,
            snapshot_timestamp: sql`NOW()`,
          }),
        )
        .execute()

      // Update user activity status when saving position snapshot
      await this.updateUserActivityStatus(accountId, depositAmountUsd, createdTimestamp)
    })
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
      referral_chain: string
      referralTimestamp: Date
    }[]
  > {
    const result = await this.db
      .selectFrom('users')
      .select(['id', 'referral_chain', 'referral_timestamp'])
      .where('referrer_id', '=', accountId)
      .execute()

    return result.map((row) => ({
      referredId: row.id,
      referral_chain: row.referral_chain,
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
      .selectFrom('users')
      .select('referrer_id')
      .where('referrer_id', 'is not', null)
      .distinct()
      .execute()

    return result.map((row) => row.referrer_id!)
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
