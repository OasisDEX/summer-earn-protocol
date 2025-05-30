import { ReferralClient } from './client'
import { DatabaseService } from './db'
import { Account, HourlySnapshot } from './types'

export interface ProcessingResult {
  success: boolean
  pointsDistributed: number
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
   * Process points for the period since last execution up to current hour
   */
  async processLatest(): Promise<ProcessingResult> {
    this.logger.log('🚀 Processing latest referral points...')

    try {
      const { periodStart, periodEnd } = await this.getProcessingPeriod()

      this.logger.log(`📅 Processing Period:`)
      this.logger.log(`   From: ${periodStart.toISOString()}`)
      this.logger.log(`   To:   ${periodEnd.toISOString()}`)

      if (periodStart >= periodEnd) {
        this.logger.log('⏰ No new data to process (already up to date)')
        return {
          success: true,
          pointsDistributed: 0,
          usersProcessed: 0,
          activeUsers: 0,
          periodStart,
          periodEnd,
        }
      }

      const result = await this.processPeriod(periodStart, periodEnd)

      if (result.success) {
        await this.updateLastExecutionTimestamp(periodEnd)
        this.logger.log(
          `✅ Successfully updated last execution timestamp to: ${periodEnd.toISOString()}`,
        )
      }

      return result
    } catch (error) {
      this.logger.error('❌ Processing failed:', error)
      return {
        success: false,
        pointsDistributed: 0,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart: new Date(),
        periodEnd: new Date(),
        error: error as Error,
      }
    }
  }

  /**
   * Backfill historical points from a given date or from the beginning
   */
  async backfill(fromDate?: Date): Promise<ProcessingResult> {
    this.logger.log('🔄 Starting historical points backfill...')

    try {
      // Check if backfill is enabled
      const config = await this.db.config.getConfig()
      if (!config.enableBackfill) {
        throw new Error(
          'Backfill is disabled in configuration. Enable it by setting enable_backfill to true.',
        )
      }

      // Determine start date
      const startDate = fromDate || (await this.getEarliestReferralDate())
      if (!startDate) {
        this.logger.log('📭 No referral data found, skipping backfill')
        return {
          success: true,
          pointsDistributed: 0,
          usersProcessed: 0,
          activeUsers: 0,
          periodStart: new Date(),
          periodEnd: new Date(),
        }
      }

      // Get end date (current hour boundary)
      const endDate = new Date()
      endDate.setMinutes(0, 0, 0)

      this.logger.log(`📅 Backfilling from ${startDate.toISOString()} to ${endDate.toISOString()}`)

      // Process hour by hour
      let currentHour = new Date(startDate)
      currentHour.setMinutes(0, 0, 0)

      let totalPointsDistributed = 0
      let totalUsersProcessed = 0
      let totalActiveUsers = 0
      const totalHours = Math.ceil((endDate.getTime() - currentHour.getTime()) / (1000 * 60 * 60))
      let processedHours = 0

      while (currentHour < endDate) {
        const nextHour = new Date(currentHour.getTime() + 60 * 60 * 1000)

        // Process this hour using the same method as regular processing
        const result = await this.processPeriod(currentHour, nextHour)

        if (result.success) {
          totalPointsDistributed += result.pointsDistributed
          totalUsersProcessed = Math.max(totalUsersProcessed, result.usersProcessed)
          totalActiveUsers = Math.max(totalActiveUsers, result.activeUsers)
        }

        currentHour = nextHour
        processedHours++

        if (processedHours % 24 === 0) {
          this.logger.log(
            `📊 Backfill progress: ${processedHours}/${totalHours} hours (${((processedHours / totalHours) * 100).toFixed(1)}%)`,
          )
        }
      }

      // Update last execution timestamp to the end of backfill
      await this.updateLastExecutionTimestamp(endDate)

      this.logger.log('✅ Historical points backfill completed')
      return {
        success: true,
        pointsDistributed: totalPointsDistributed,
        usersProcessed: totalUsersProcessed,
        activeUsers: totalActiveUsers,
        periodStart: startDate,
        periodEnd: endDate,
      }
    } catch (error) {
      this.logger.error('❌ Backfill failed:', error)
      return {
        success: false,
        pointsDistributed: 0,
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

    let pointsDistributed = 0
    let usersProcessed = 0
    let activeUsers = 0

    try {
      // Step 1: Fetch data from subgraph for this period

      // Check if this is the first run
      const isFirstRun = await this.isFirstRun()

      const timestampGt = isFirstRun ? BigInt(0) : BigInt(Math.floor(periodStart.getTime() / 1000))
      const timestampLt = BigInt(Math.floor(periodEnd.getTime() / 1000))

      this.logger.log(`📡 Fetching data from subgraph (First run: ${isFirstRun})...`)

      // Get NEW REFERRED ACCOUNTS IN THIS PERIOD AND VALIDATE THEM
      const { validAccounts: newValidAccounts } = await this.client.getValidReferredAccounts(
        timestampGt,
        timestampLt,
      )

      this.logger.log(`📊 Found ${newValidAccounts.length} valid accounts`)
      await this.storeNewAccounts(newValidAccounts)
      const allAccountIds = await this.getAllAccountIds()

      this.logger.log(`🔍 All account IDs: ${allAccountIds.length}`)

      // Step 2: Get position snapshots for valid accounts
      if (newValidAccounts.length > 0 || !isFirstRun) {
        const accountsWithSnapshots = await this.client.getAllPositionsWithHourlySnapshots(
          allAccountIds,
          { timestampGt, timestampLt },
        )
        // Step 3: Store the snapshot data in database
        await this.storeSnapshotData(accountsWithSnapshots, periodStart, periodEnd)
      }

      // Step 4: Update user activity status based on the new snapshots
      await this.updateUserActivityForPeriod(periodStart, periodEnd)

      // Step 5: Get ALL referral relationships after updating data
      const allReferralData = await this.db.getReferralRelationshipsWithActiveUsers()

      if (allReferralData.length === 0) {
        this.logger.log('📭 No referral relationships found')
        return {
          success: true,
          pointsDistributed: 0,
          usersProcessed: 0,
          activeUsers: 0,
          periodStart,
          periodEnd,
        }
      }

      this.logger.log(`👥 Found ${allReferralData.length} referrers with referral relationships`)

      // Get configuration
      const config = await this.db.config.getConfig()

      // Calculate total active users
      const allActiveUserIds = new Set<string>()
      allReferralData.forEach(({ referredUsers }) => {
        referredUsers.forEach((user) => {
          if (user.isActive) {
            allActiveUserIds.add(user.referredId)
          }
        })
      })
      activeUsers = allActiveUserIds.size

      this.logger.log(`🟢 Total active users: ${activeUsers}`)

      // Process each referrer
      const pointDistributions: Array<{
        accountId: string
        referrerId: string
        pointsAwarded: number
        totalDepositsUsd: number
        activeReferredUsers: number
      }> = []

      for (const { referrerId, referredUsers } of allReferralData) {
        const activeReferredUsers = referredUsers.filter((user) => user.isActive)

        if (activeReferredUsers.length === 0) {
          continue
        }

        const totalDepositsUsd = activeReferredUsers.reduce(
          (sum, user) => sum + user.totalDepositsUsd,
          0,
        )

        // Calculate points using formula: deposits * (base + log_multiplier * ln(total_active_users + 1))
        const points =
          totalDepositsUsd *
          (config.pointsFormulaBase + config.pointsFormulaLogMultiplier * Math.log(activeUsers + 1))

        if (points > 0) {
          pointDistributions.push({
            accountId: referrerId,
            referrerId: referrerId,
            pointsAwarded: points,
            totalDepositsUsd,
            activeReferredUsers: activeReferredUsers.length,
          })

          pointsDistributed += points
          usersProcessed++
        }
      }

      // Record all point distributions
      if (pointDistributions.length > 0) {
        this.logger.log(`💾 Recording ${pointDistributions.length} point distributions...`)

        for (const distribution of pointDistributions) {
          await this.db.recordPointDistribution(
            distribution.accountId,
            distribution.referrerId,
            distribution.pointsAwarded,
            distribution.totalDepositsUsd,
            distribution.activeReferredUsers,
            periodStart,
            periodEnd,
          )
        }
      }

      this.logger.log(
        `📈 Period complete: ${pointsDistributed.toFixed(8)} points distributed to ${usersProcessed} users`,
      )

      return {
        success: true,
        pointsDistributed,
        usersProcessed,
        activeUsers,
        periodStart,
        periodEnd,
      }
    } catch (error) {
      this.logger.error('❌ Error during period processing:', error)
      return {
        success: false,
        pointsDistributed: 0,
        usersProcessed: 0,
        activeUsers: 0,
        periodStart,
        periodEnd,
        error: error as Error,
      }
    }
  }

  /**
   * Store snapshot data from subgraph into database
   */
  private async storeSnapshotData(
    accountsWithSnapshots: { [chain: string]: Account[] },
    periodStart: Date,
    periodEnd: Date,
  ): Promise<void> {
    this.logger.log('💾 Storing snapshot data from subgraph...')

    for (const [chain, accounts] of Object.entries(accountsWithSnapshots)) {
      for (const account of accounts) {
        // Store referral relationships if account has referral data
        // todo : thats moved elswhere
        // if (account.referralData && account.referralTimestamp) {
        //   await this.db.upsertReferralRelationship(
        //     account.referralData.id,
        //     account.id,
        //     chain as any,
        //     new Date(Number(account.referralTimestamp) * 1000),
        //   )
        // }

        // Process each position and its hourly snapshots
        if (account.positions) {
          for (const position of account.positions) {
            // Process hourly snapshots for this position
            if (position.hourlySnapshots && position.hourlySnapshots.length > 0) {
              await this.processPositionSnapshots(
                account,
                position,
                chain as any,
                periodStart,
                periodEnd,
              )
            }
          }
        }
      }
    }
  }

  /**
   * Process position snapshots for a specific period
   */
  private async processPositionSnapshots(
    account: Account,
    position: any,
    chain: any,
    periodStart: Date,
    periodEnd: Date,
  ): Promise<void> {
    // Get the most recent snapshot within the time period
    const relevantSnapshots = position.hourlySnapshots.filter((snapshot: HourlySnapshot) => {
      const snapshotTime = new Date(Number(snapshot.timestamp) * 1000)
      return snapshotTime >= periodStart && snapshotTime <= periodEnd
    })

    if (relevantSnapshots.length === 0) {
      this.logger.log(
        `No snapshots found for position ${position.id} in period ${periodStart.toISOString()} - ${periodEnd.toISOString()}`,
      )
      return
    }

    // Use the latest snapshot within the period
    const latestSnapshot = relevantSnapshots.reduce(
      (latest: HourlySnapshot, current: HourlySnapshot) => {
        return Number(current.timestamp) > Number(latest.timestamp) ? current : latest
      },
    )

    const depositAmount = Number(latestSnapshot.inputTokenBalanceNormalizedInUSD || 0)
    const snapshotTimestamp = new Date(Number(latestSnapshot.timestamp) * 1000)
    const createdTimestamp = new Date(Number(position.createdTimestamp) * 1000)

    // Store position snapshot with balance from hourly snapshot
    await this.db.savePositionSnapshot(
      account.id,
      chain,
      position.id,
      depositAmount,
      createdTimestamp,
      account.referralTimestamp ? new Date(Number(account.referralTimestamp) * 1000) : undefined,
    )
  }

  /**
   * Check if this is the first run
   */
  private async isFirstRun(): Promise<boolean> {
    try {
      return !(await this.db.hasAnyData())
    } catch (error) {
      this.logger.error('Error checking if first run:', error)
      return true // Assume first run on error
    }
  }

  /**
   * Get all account IDs from the database
   */
  private async getAllAccountIds(): Promise<string[]> {
    const result = await this.db.rawDb.query(
      'SELECT DISTINCT id FROM users WHERE referral_timestamp IS NOT NULL',
    )
    return result.rows.map((row) => row.id)
  }

  private async storeNewAccounts(newValidAccounts: Account[]): Promise<void> {
    this.logger.log(`💾 Storing ${newValidAccounts.length} new referred accounts...`)

    const accountsToStore = newValidAccounts.map((account) => ({
      referrerId: account.referralData?.id || null,
      referredId: account.id,
      referredChain: account.referralChain!,
      referralTimestamp: new Date(Number(account.referralTimestamp) * 1000),
    }))

    await this.db.storeReferredAccounts(accountsToStore)
  }

  /**
   * Get processing statistics
   */
  async getStats(): Promise<{
    lastExecution: Date | null
    nextScheduledExecution: Date
    hoursUntilNext: number
    totalReferrers: number
    totalActiveUsers: number
    totalPointDistributions: number
    topReferrers: Array<{
      accountId: string
      points: number
      totalDepositsUsd: number
      activeReferredUsers: number
    }>
  }> {
    const lastExecution = await this.getLastExecutionTimestamp()

    const now = new Date()
    const nextHour = new Date(now)
    nextHour.setHours(nextHour.getHours() + 1, 0, 0, 0)

    const hoursUntilNext = (nextHour.getTime() - now.getTime()) / (1000 * 60 * 60)

    // Get database statistics
    const [referrersResult, activeUsersResult, distributionsResult] = await Promise.all([
      this.db.rawDb.query(
        'SELECT COUNT(DISTINCT referrer_id) as count FROM users WHERE referrer_id IS NOT NULL',
      ),
      this.db.rawDb.query(
        'SELECT COUNT(*) as count FROM user_activity_status WHERE is_active = true',
      ),
      this.db.rawDb.query('SELECT COUNT(*) as count FROM point_distributions'),
    ])

    // Get top referrers
    const topReferrersQuery = `
      SELECT 
        account_id,
        points,
        total_deposits_usd,
        active_referred_users
      FROM referral_points
      ORDER BY points DESC
      LIMIT 10
    `
    const topReferrersResult = await this.db.rawDb.query(topReferrersQuery)

    return {
      lastExecution,
      nextScheduledExecution: nextHour,
      hoursUntilNext,
      totalReferrers: parseInt(referrersResult.rows[0]?.count || '0'),
      totalActiveUsers: parseInt(activeUsersResult.rows[0]?.count || '0'),
      totalPointDistributions: parseInt(distributionsResult.rows[0]?.count || '0'),
      topReferrers: topReferrersResult.rows.map((row) => ({
        accountId: row.account_id,
        points: Number(row.points),
        totalDepositsUsd: Number(row.total_deposits_usd),
        activeReferredUsers: row.active_referred_users,
      })),
    }
  }

  /**
   * Clean up resources
   */
  async close(): Promise<void> {
    await this.db.close()
  }

  // Private helper methods

  private async getProcessingPeriod(): Promise<{ periodStart: Date; periodEnd: Date }> {
    const lastExecution = await this.getLastExecutionTimestamp()

    const now = new Date()
    const currentHourStart = new Date(now)
    currentHourStart.setMinutes(0, 0, 0)

    let periodStart: Date
    if (!lastExecution) {
      periodStart = new Date(currentHourStart.getTime() - 24 * 60 * 60 * 1000)
      this.logger.log('📍 No previous execution found, starting from 24 hours ago')
    } else {
      periodStart = lastExecution
    }

    return {
      periodStart,
      periodEnd: currentHourStart,
    }
  }

  private async getLastExecutionTimestamp(): Promise<Date | null> {
    try {
      const result = await this.db.rawDb.query('SELECT value FROM points_config WHERE key = $1', [
        'last_execution_timestamp',
      ])
      return result.rows[0]?.value ? new Date(result.rows[0].value) : null
    } catch (error) {
      this.logger.log('📍 No last execution timestamp found')
      return null
    }
  }

  private async updateLastExecutionTimestamp(timestamp: Date): Promise<void> {
    await this.db.rawDb.query(
      `INSERT INTO points_config (key, value, description, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())
       ON CONFLICT (key) DO UPDATE SET 
         value = $2, 
         updated_at = NOW()`,
      [
        'last_execution_timestamp',
        timestamp.toISOString(),
        'Timestamp of last successful execution',
      ],
    )
  }

  private async updateUserActivityForPeriod(periodStart: Date, periodEnd: Date): Promise<void> {
    this.logger.log('🔄 Updating user activity status...')

    // Update activity for users with deposits in this period
    const query = `
      SELECT 
        ps.account_id,
        SUM(
          CASE 
            WHEN ps.deposit_amount_usd > 0 THEN ps.deposit_amount_usd 
            ELSE 0 
          END
        ) as total_deposits,
        MAX(ps.created_timestamp) as last_deposit
      FROM position_snapshots ps
      WHERE ps.snapshot_timestamp >= $1 AND ps.snapshot_timestamp < $2
      GROUP BY ps.account_id
      HAVING SUM(
        CASE 
          WHEN ps.deposit_amount_usd > 0 THEN ps.deposit_amount_usd 
          ELSE 0 
        END
      ) > 0
    `

    const result = await this.db.rawDb.query(query, [periodStart, periodEnd])

    for (const row of result.rows) {
      await this.db.updateUserActivityStatus(
        row.account_id,
        Number(row.total_deposits),
        row.last_deposit,
      )
    }

    // Also refresh all users with historical deposits
    const allUsersQuery = `
      SELECT 
        ps.account_id,
        SUM(
          CASE 
            WHEN ps.deposit_amount_usd > 0 THEN ps.deposit_amount_usd 
            ELSE 0 
          END
        ) as total_deposits,
        MAX(ps.created_timestamp) as last_deposit
      FROM position_snapshots ps
      GROUP BY ps.account_id
      HAVING SUM(
        CASE 
          WHEN ps.deposit_amount_usd > 0 THEN ps.deposit_amount_usd 
          ELSE 0 
        END
      ) > 0
    `

    const allUsersResult = await this.db.rawDb.query(allUsersQuery)

    for (const row of allUsersResult.rows) {
      await this.db.updateUserActivityStatus(
        row.account_id,
        Number(row.total_deposits),
        row.last_deposit,
      )
    }
  }

  private async getEarliestReferralDate(): Promise<Date | null> {
    try {
      const result = await this.db.rawDb.query(
        'SELECT MIN(referral_timestamp) as earliest_referral FROM users WHERE referral_timestamp IS NOT NULL',
      )
      return result.rows[0]?.earliest_referral || null
    } catch (error) {
      this.logger.error('Error getting earliest referral date:', error)
      return null
    }
  }
}
