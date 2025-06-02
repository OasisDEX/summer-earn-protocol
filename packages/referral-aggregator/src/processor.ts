import { ReferralClient } from './client'
import { DatabaseService } from './db'
import { HourlySnapshot } from './types'

export interface ProcessingResult {
  success: boolean
  usersProcessed: number
  activeUsers: number
  periodStart: Date
  periodEnd: Date
  error?: Error
}

export interface ProcessorConfig {
  logger?: Logger
}

export interface Logger {
  log(...args: any[]): void
  error(...args: any[]): void
  warn(...args: any[]): void
}

export class ReferralProcessor {
  private db: DatabaseService
  private client: ReferralClient
  private logger: Logger

  constructor(config?: ProcessorConfig) {
    this.db = new DatabaseService()
    this.client = new ReferralClient()
    this.logger = config?.logger || console
  }

  /**
   * Process the latest period since last execution
   */
  async processLatest(): Promise<ProcessingResult> {
    this.logger.log('🚀 Processing latest referral points...')

    try {
      const lastProcessed = await this.db.getLastProcessedTimestamp()
      const now = new Date()
      now.setMinutes(0, 0, 0) // Round down to hour

      let periodStart: Date
      if (!lastProcessed) {
        // First run - process last 24 hours
        periodStart = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000)
        this.logger.log('📍 First run - processing last 24 hours')
      } else {
        periodStart = lastProcessed
      }

      const periodEnd = now

      this.logger.log(`📅 Processing Period:`)
      this.logger.log(`   From: ${periodStart.toISOString()}`)
      this.logger.log(`   To:   ${periodEnd.toISOString()}`)

      if (periodStart >= periodEnd) {
        this.logger.log('⏰ No new data to process')
        return {
          success: true,
          usersProcessed: 0,
          activeUsers: 0,
          periodStart,
          periodEnd,
        }
      }

      // if period is longer than 1 hour, we need to process it in chunks of 1 hour
      if (periodEnd.getTime() - periodStart.getTime() > 1 * 60 * 60 * 1000) {
        const chunks = Math.ceil(
          (periodEnd.getTime() - periodStart.getTime()) / (1 * 60 * 60 * 1000),
        )
        for (let i = 0; i < chunks; i++) {
          const chunkStart = new Date(periodStart.getTime() + i * 1 * 60 * 60 * 1000)
          const chunkEnd = new Date(periodStart.getTime() + (i + 1) * 1 * 60 * 60 * 1000)
          const result = await this.processPeriod(chunkStart, chunkEnd)
          if (!result.success) {
            return result
          } else {
            await this.db.updateProcessingCheckpoint(chunkEnd)
            this.logger.log(`✅ Checkpoint updated to: ${chunkEnd.toISOString()}`)
          }
        }
      } else {
        const result = await this.processPeriod(periodStart, periodEnd)
        if (!result.success) {
          return result
        } else {
          await this.db.updateProcessingCheckpoint(periodEnd)
          this.logger.log(`✅ Checkpoint updated to: ${periodEnd.toISOString()}`)
        }
      }

      return {
        success: true,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart,
        periodEnd,
      }
    } catch (error) {
      this.logger.error('❌ Processing failed:', error)
      return {
        success: false,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart: new Date(),
        periodEnd: new Date(),
        error: error as Error,
      }
    }
  }

  /**
   * Process a specific time period
   */
  async processPeriod(periodStart: Date, periodEnd: Date): Promise<ProcessingResult> {
    this.logger.log(
      `\n🔄 Processing period: ${periodStart.toISOString()} → ${periodEnd.toISOString()}`,
    )

    try {
      // Step 1: Fetch new referred accounts in this period
      const timestampGt = BigInt(Math.floor(periodStart.getTime() / 1000))
      const timestampLt = BigInt(Math.floor(periodEnd.getTime() / 1000))

      this.logger.log(`📡 Fetching referred accounts...`)
      const { validAccounts } = await this.client.getValidReferredAccounts(timestampGt, timestampLt)

      this.logger.log(`📊 Found ${validAccounts.length} new valid referred accounts`)

      // Store new users
      for (const account of validAccounts) {
        await this.db.upsertUser(account.id, {
          referrerId: account.referralData?.id,
          referralChain: account.referralChain,
          referralTimestamp: new Date(Number(account.referralTimestamp) * 1000),
        })
      }

      // Step 2: Get all users that need position updates
      const allUsers = await this.db.rawDb.selectFrom('users').select('id').execute()

      const userIds = allUsers.map((u) => u.id)
      this.logger.log(`📊 Updating positions for ${userIds.length} users...`)

      // Step 3: Fetch and update positions
      const positionsByChain = await this.client.getAllPositionsWithHourlySnapshots(userIds, {
        timestampGt,
        timestampLt,
      })
      // console.log("positionsByChain", positionsByChain)
      // Update positions and user totals
      for (const [chain, accounts] of Object.entries(positionsByChain)) {
        for (const account of accounts) {
          if (account.positions) {
            for (const position of account.positions) {
              // Find the latest snapshot in the period
              const latestSnapshot = this.getLatestSnapshot(
                position.hourlySnapshots,
                periodStart,
                periodEnd,
              )
              if (latestSnapshot) {
                const depositUsd = Number(latestSnapshot.inputTokenBalanceNormalizedInUSD || 0)
                await this.db.updatePosition(position.id, chain as any, account.id, depositUsd)
              }
            }
            // Update user totals after all positions are updated
            await this.db.updateUserTotals(account.id)
          }
        }
      }

      // Step 4: Recalculate all referral stats
      this.logger.log('📊 Recalculating referral stats...')
      await this.db.recalculateReferralStats()

      // Step 5: Update daily rates and accumulate points
      this.logger.log('💰 Updating points and daily rates...')
      await this.db.updateDailyRatesAndPoints()

      // Step 6: Update daily stats for historical tracking
      await this.db.updateDailyStats()

      // Get final stats
      const activeUsersResult = await this.db.rawDb
        .selectFrom('users')
        .select((eb) => eb.fn.count('id').as('count'))
        .where('is_active', '=', true)
        .executeTakeFirst()

      const activeUsers = Number(activeUsersResult?.count || 0)

      this.logger.log(
        `✅ Period complete: ${userIds.length} users processed, ${activeUsers} active users`,
      )

      return {
        success: true,
        usersProcessed: userIds.length,
        activeUsers,
        periodStart,
        periodEnd,
      }
    } catch (error) {
      this.logger.error('❌ Error during period processing:', error)
      return {
        success: false,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart,
        periodEnd,
        error: error as Error,
      }
    }
  }

  /**
   * Get the latest snapshot within a time period
   */
  private getLatestSnapshot(
    snapshots: HourlySnapshot[] | undefined,
    periodStart: Date,
    periodEnd: Date,
  ): HourlySnapshot | null {
    if (!snapshots || snapshots.length === 0) return null
    const relevantSnapshots = snapshots.filter((snapshot) => {
      const snapshotTime = new Date(Number(snapshot.timestamp) * 1000)
      return snapshotTime >= periodStart && snapshotTime <= periodEnd
    })

    if (relevantSnapshots.length === 0) return null

    return relevantSnapshots.reduce((latest, current) => {
      return Number(current.timestamp) > Number(latest.timestamp) ? current : latest
    })
  }

  /**
   * Backfill historical data
   */
  async backfill(fromDate?: Date): Promise<ProcessingResult> {
    this.logger.log('🔄 Starting historical backfill...')

    try {
      // Get earliest referral date
      const earliestResult = await this.db.rawDb
        .selectFrom('users')
        .select((eb) => eb.fn.min('referral_timestamp').as('earliest'))
        .where('referral_timestamp', 'is not', null)
        .executeTakeFirst()

      const startDate = fromDate || earliestResult?.earliest || new Date()
      const endDate = new Date()
      endDate.setMinutes(0, 0, 0)

      this.logger.log(`📅 Backfilling from ${startDate.toISOString()} to ${endDate.toISOString()}`)

      // Process in chunks of 24 hours
      let currentStart = new Date(startDate)
      currentStart.setHours(0, 0, 0, 0)

      let totalUsers = 0
      let totalActive = 0

      while (currentStart < endDate) {
        const currentEnd = new Date(currentStart.getTime() + 24 * 60 * 60 * 1000)

        const result = await this.processPeriod(currentStart, currentEnd)
        if (result.success) {
          totalUsers = Math.max(totalUsers, result.usersProcessed)
          totalActive = Math.max(totalActive, result.activeUsers)
        }

        currentStart = currentEnd
      }

      // Update checkpoint
      await this.db.updateProcessingCheckpoint(endDate)

      this.logger.log('✅ Backfill completed')
      return {
        success: true,
        usersProcessed: totalUsers,
        activeUsers: totalActive,
        periodStart: startDate,
        periodEnd: endDate,
      }
    } catch (error) {
      this.logger.error('❌ Backfill failed:', error)
      return {
        success: false,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart: new Date(),
        periodEnd: new Date(),
        error: error as Error,
      }
    }
  }

  /**
   * Get processing statistics
   */
  async getStats(): Promise<{
    lastProcessed: Date | null
    totalReferralCodes: number
    totalActiveUsers: number
    topReferrers: Array<{
      id: string
      customCode: string | null
      totalPoints: number
      pointsPerDay: number
      activeUsers: number
      totalDeposits: number
    }>
  }> {
    const lastProcessed = await this.db.getLastProcessedTimestamp()

    // Get stats
    const [referralCodesResult, activeUsersResult] = await Promise.all([
      this.db.rawDb
        .selectFrom('referral_codes')
        .select((eb) => eb.fn.count('id').as('count'))
        .executeTakeFirst(),
      this.db.rawDb
        .selectFrom('users')
        .select((eb) => eb.fn.count('id').as('count'))
        .where('is_active', '=', true)
        .executeTakeFirst(),
    ])

    // Get top referrers
    const topReferrers = await this.db.getTopReferralCodes(10)

    return {
      lastProcessed,
      totalReferralCodes: Number(referralCodesResult?.count || 0),
      totalActiveUsers: Number(activeUsersResult?.count || 0),
      topReferrers: topReferrers.map((r) => ({
        id: r.id,
        customCode: r.custom_code,
        totalPoints: r.total_points,
        pointsPerDay: r.points_per_day,
        activeUsers: r.active_users_count,
        totalDeposits: r.total_deposits_usd,
      })),
    }
  }

  /**
   * Clean up resources
   */
  async close(): Promise<void> {
    await this.db.close()
  }
}
