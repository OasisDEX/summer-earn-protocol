import { Kysely, PostgresDialect, sql } from 'kysely'
import { DB } from 'kysely-codegen'
import { Pool } from 'pg'
import { ConfigService } from './config-updated'
import { KyselyMigrator } from './migrations/kysely-migrator'
import { Chain } from './types'

export interface SimplifiedReferralCode {
  id: string
  custom_code: string | null
  total_points: number
  total_deposits_usd: number
  active_users_count: number
  points_per_day: number
  deposits_per_day: number
  last_calculated_at: Date | null
  created_at: Date
  updated_at: Date
}

export interface SimplifiedUser {
  id: string
  referrer_id: string | null
  referral_chain: string | null
  referral_timestamp: Date | null
  total_deposits_usd: number
  is_active: boolean
  last_activity_at: Date | null
  created_at: Date
  updated_at: Date
}

export interface SimplifiedPosition {
  id: string
  chain: string
  user_id: string
  current_deposit_usd: number
  last_synced_at: Date | null
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

  /**
   * Utility Operations
   */
  async hasAnyData(): Promise<boolean> {
    const result = await this.db
      .selectFrom('users')
      .select((eb) => eb.fn.count('id').as('count'))
      .executeTakeFirst()

    return (result?.count as any) > 0
  }

  /**
   * Get or create referral code
   */
  async ensureReferralCode(id: string, customCode?: string): Promise<void> {
    await this.db
      .insertInto('referral_codes')
      .values({
        id,
        custom_code: customCode || null,
        total_points: '0',
        total_deposits_usd: '0',
        active_users_count: 0,
        points_per_day: '0',
        deposits_per_day: '0',
      })
      .onConflict((oc) => oc.column('id').doNothing())
      .execute()
  }

  /**
   * Create or update user with referral info
   */
  async upsertUser(
    userId: string,
    data: {
      referrerId?: string
      referralChain?: Chain
      referralTimestamp?: Date
    },
  ): Promise<void> {
    // Ensure referral code exists for referrer
    if (data.referrerId) {
      await this.ensureReferralCode(data.referrerId)
    }

    await this.db
      .insertInto('users')
      .values({
        id: userId,
        referrer_id: data.referrerId || null,
        referral_chain: data.referralChain || null,
        referral_timestamp: data.referralTimestamp || null,
        total_deposits_usd: '0',
        is_active: false,
      })
      .onConflict((oc) => oc.doNothing())
      .execute()
  }

  /**
   * Update position state (idempotent)
   */
  async updatePosition(
    positionId: string,
    chain: Chain,
    userId: string,
    depositUsd: number,
  ): Promise<void> {
    await this.db
      .insertInto('positions')
      .values({
        id: positionId,
        chain,
        user_id: userId,
        current_deposit_usd: depositUsd.toString(),
        last_synced_at: new Date(),
      })
      .onConflict((oc) =>
        oc.columns(['id', 'chain']).doUpdateSet({
          current_deposit_usd: depositUsd.toString(),
          last_synced_at: new Date(),
        }),
      )
      .execute()
  }

  /**
   * Update user deposit totals and activity status
   */
  async updateUserTotals(userId: string): Promise<void> {
    const config = await this.config.getConfig()

    // Calculate total deposits from all positions
    const result = await this.db
      .selectFrom('positions')
      .select((eb) => eb.fn.sum('current_deposit_usd').as('total_deposits'))
      .where('user_id', '=', userId)
      .executeTakeFirst()

    const totalDeposits = Number(result?.total_deposits || 0)
    const isActive = totalDeposits >= Number(config.activeUserThresholdUsd)

    await this.db
      .updateTable('users')
      .set({
        total_deposits_usd: totalDeposits.toString(),
        is_active: isActive,
        last_activity_at: new Date(),
      })
      .where('id', '=', userId)
      .execute()
  }

  /**
   * Recalculate all referral stats (fast single query)
   */
  async recalculateReferralStats(): Promise<void> {
    await this.db.executeQuery(
      sql`
      UPDATE referral_codes rc
      SET 
        active_users_count = COALESCE(stats.active_users, 0),
        total_deposits_usd = COALESCE(stats.total_deposits, '0'),
        updated_at = NOW()
      FROM (
        SELECT 
          referrer_id,
          COUNT(*) FILTER (WHERE is_active) as active_users,
          SUM(total_deposits_usd) as total_deposits
        FROM users
        WHERE referrer_id IS NOT NULL
        GROUP BY referrer_id
      ) stats
      WHERE rc.id = stats.referrer_id
    `.compile(this.db),
    )
  }

  /**
   * Update daily rates and accumulate points
   */
  async updateDailyRatesAndPoints(): Promise<void> {
    const config = await this.config.getConfig()

    await this.db.executeQuery(
      sql`
      WITH active_users_per_code AS (
        SELECT referrer_id, COUNT(*) as active_users
        FROM users 
        WHERE is_active = true AND referrer_id IS NOT NULL
        GROUP BY referrer_id
      )
      UPDATE referral_codes rc
      SET 
        points_per_day = rc.total_deposits_usd * (${config.pointsFormulaBase} + ${config.pointsFormulaLogMultiplier} * ln(COALESCE(auc.active_users, 0) + 1)),
        deposits_per_day = CASE 
          WHEN EXTRACT(epoch FROM (NOW() - rc.created_at)) > 0 
          THEN rc.total_deposits_usd / (EXTRACT(epoch FROM (NOW() - rc.created_at)) / 86400)
          ELSE 0
        END,
        -- Accumulate points (hourly rate)
        total_points = rc.total_points + (
          rc.total_deposits_usd * (${config.pointsFormulaBase} + ${config.pointsFormulaLogMultiplier} * ln(COALESCE(auc.active_users, 0) + 1)) / 24
        ),
        last_calculated_at = NOW()
      FROM active_users_per_code auc
      WHERE rc.id = auc.referrer_id
      AND rc.active_users_count > 0
      `.compile(this.db),
    )

    // Insert new point distributions
    await this.db.executeQuery(
      sql`
      INSERT INTO points_distributions (referral_id, points_amount, description)
      SELECT id, points_per_day / 24, 'REGULAR' FROM referral_codes
      WHERE active_users_count > 0
    `.compile(this.db),
    )
  }

  /**
   * Update daily stats for historical tracking
   */
  async updateDailyStats(): Promise<void> {
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    await this.db.executeQuery(
      sql`
      INSERT INTO daily_stats (referral_id, date, points_earned, active_users, total_deposits)
      SELECT 
        id as referral_id,
        ${today}::date as date,
        points_per_day as points_earned,
        active_users_count as active_users,
        total_deposits_usd as total_deposits
      FROM referral_codes
      WHERE active_users_count > 0
      ON CONFLICT (referral_id, date) 
      DO UPDATE SET
        points_earned = EXCLUDED.points_earned,
        active_users = EXCLUDED.active_users,
        total_deposits = EXCLUDED.total_deposits
    `.compile(this.db),
    )
  }

  /**
   * Get processing checkpoint
   */
  async getLastProcessedTimestamp(): Promise<Date | null> {
    const result = await this.db
      .selectFrom('processing_checkpoint')
      .select('last_processed_timestamp')
      .orderBy('id', 'desc')
      .limit(1)
      .executeTakeFirst()

    return result?.last_processed_timestamp || null
  }

  /**
   * Update processing checkpoint
   */
  async updateProcessingCheckpoint(timestamp: Date): Promise<void> {
    await this.db
      .insertInto('processing_checkpoint')
      .values({
        last_processed_timestamp: timestamp,
      })
      .execute()
  }

  /**
   * Get referral code with stats
   */
  async getReferralCode(id: string): Promise<SimplifiedReferralCode | null> {
    const result = await this.db
      .selectFrom('referral_codes')
      .selectAll()
      .where('id', '=', id)
      .executeTakeFirst()

    if (!result) return null

    return {
      ...result,
      total_points: Number(result.total_points),
      total_deposits_usd: Number(result.total_deposits_usd),
      points_per_day: Number(result.points_per_day),
      deposits_per_day: Number(result.deposits_per_day),
      created_at: result.created_at || new Date(),
      updated_at: result.updated_at || new Date(),
    }
  }

  /**
   * Get users referred by a referral code
   */
  async getUsersReferredBy(referrerId: string): Promise<SimplifiedUser[]> {
    const results = await this.db
      .selectFrom('users')
      .selectAll()
      .where('referrer_id', '=', referrerId)
      .execute()

    return results.map((row) => ({
      ...row,
      total_deposits_usd: Number(row.total_deposits_usd),
      created_at: row.created_at || new Date(),
      updated_at: row.updated_at || new Date(),
    }))
  }

  /**
   * Get active users referred by a referral code
   */
  async getActiveUsersReferredBy(referrerId: string): Promise<SimplifiedUser[]> {
    const results = await this.db
      .selectFrom('users')
      .selectAll()
      .where('referrer_id', '=', referrerId)
      .where('is_active', '=', true)
      .execute()

    return results.map((row) => ({
      ...row,
      total_deposits_usd: Number(row.total_deposits_usd),
      created_at: row.created_at || new Date(),
      updated_at: row.updated_at || new Date(),
    }))
  }

  /**
   * Get all referral codes with stats for leaderboard
   */
  async getTopReferralCodes(limit: number = 100): Promise<SimplifiedReferralCode[]> {
    const results = await this.db
      .selectFrom('referral_codes')
      .selectAll()
      .orderBy('total_points', 'desc')
      .limit(limit)
      .execute()

    return results.map((row) => ({
      ...row,
      total_points: Number(row.total_points),
      total_deposits_usd: Number(row.total_deposits_usd),
      points_per_day: Number(row.points_per_day),
      deposits_per_day: Number(row.deposits_per_day),
      created_at: row.created_at || new Date(),
      updated_at: row.updated_at || new Date(),
    }))
  }

  async close(): Promise<void> {
    await this.db.destroy()
  }

  get rawDb() {
    return this.db
  }

  get rawPool() {
    return this.pool
  }
}
