import { ReferralClient } from './client'
import { DatabaseService } from './db'
import { EnhancedReferralPointsService } from './enhanced-points'
import { Account, HourlySnapshot } from './types'

export class EnhancedHourlyProcessor {
  private pointsService: EnhancedReferralPointsService
  private processingInterval?: NodeJS.Timeout

  constructor(
    private client: ReferralClient,
    private db: DatabaseService,
  ) {
    this.pointsService = new EnhancedReferralPointsService(db, client)
  }

  async processHourly(): Promise<void> {
    const now = new Date()
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000)

    // Check if this is the first run by looking for any existing data
    const isFirstRun = await this.isFirstRun()

    console.log(`Starting hourly processing - First run: ${isFirstRun}`)

    // Process using hourly snapshots for more accurate data
    await this.processWithHourlySnapshots(oneHourAgo, now, isFirstRun)

    console.log('Hourly processing completed')
  }

  private async processWithHourlySnapshots(
    periodStart: Date,
    periodEnd: Date,
    isFirstRun: boolean,
  ): Promise<void> {
    const timestampGt = BigInt(Math.floor(periodStart.getTime() / 1000))
    const timestampLt = BigInt(Math.floor(periodEnd.getTime() / 1000))

    // Step 1: Get all referred accounts with snapshot data
    const { validAccounts, allReferredAccounts } =
      await this.client.processReferredAccountsHourlyWithSnapshots(
        timestampGt,
        timestampLt,
        isFirstRun,
      )

    console.log(
      `Found ${allReferredAccounts.length} referred accounts, ${validAccounts.length} valid`,
    )

    if (validAccounts.length === 0 && !isFirstRun) {
      console.log('No new accounts found, proceeding with points calculation for existing data')
    } else {
      // Step 2: Get accounts with hourly snapshots for the specific time period
      const accountsWithSnapshots = await this.client.getAllPositionsWithHourlySnapshots(
        validAccounts,
        { timestampGt, timestampLt },
      )

      // Step 3: Store the snapshot data in database
      await this.storeSnapshotData(accountsWithSnapshots, periodStart, periodEnd)
    }

    // Step 4: Calculate hourly points for the period
    await this.processHourlyPoints(periodStart, periodEnd)
  }

  private async storeSnapshotData(
    accountsWithSnapshots: { [chain: string]: Account[] },
    periodStart: Date,
    periodEnd: Date,
  ): Promise<void> {
    for (const [chain, accounts] of Object.entries(accountsWithSnapshots)) {
      for (const account of accounts) {
        // Store referral relationships if account has referral data
        if (account.referralData && account.referralTimestamp) {
          await this.db.upsertReferralRelationship(
            account.referralData.id,
            account.id,
            chain as any,
            new Date(Number(account.referralTimestamp) * 1000),
          )
        }

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
      console.log(
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

    console.log(
      `Processing snapshot for position ${position.id}: $${depositAmount} at ${snapshotTimestamp.toISOString()}`,
    )

    // Store position snapshot with balance from hourly snapshot
    await this.db.savePositionSnapshot(
      account.id,
      chain,
      position.id,
      depositAmount,
      createdTimestamp,
      account.referralTimestamp ? new Date(Number(account.referralTimestamp) * 1000) : undefined,
    )

    // Update user activity status based on snapshot data
    await this.db.updateUserActivityStatus(account.id, depositAmount, snapshotTimestamp)
  }

  private async processHourlyPoints(periodStart: Date, periodEnd: Date): Promise<void> {
    console.log('Starting hourly points calculation...')

    try {
      // Calculate points for the hour
      await this.pointsService.calculateHourlyPoints(periodStart, periodEnd)
    } catch (error) {
      console.error('Error calculating hourly points:', error)
      throw error
    }
  }

  private async isFirstRun(): Promise<boolean> {
    try {
      return !(await this.db.hasAnyData())
    } catch (error) {
      console.error('Error checking if first run:', error)
      return true // Assume first run on error
    }
  }

  // Legacy method for backward compatibility with current position data
  private async storeAccountsAndPositions(accountsWithPositions: {
    [chain: string]: Account[]
  }): Promise<void> {
    for (const [chain, accounts] of Object.entries(accountsWithPositions)) {
      for (const account of accounts) {
        // Store referral relationships if account has referral data
        if (account.referralData && account.referralTimestamp) {
          await this.db.upsertReferralRelationship(
            account.referralData.id,
            account.id,
            chain as any,
            new Date(Number(account.referralTimestamp) * 1000),
          )
        }

        // Store position snapshots and update user activity
        if (account.positions) {
          let totalUserDeposits = 0
          let latestTimestamp: Date | undefined

          for (const position of account.positions) {
            const depositAmount = Number(position.inputTokenBalanceNormalizedInUSD || 0)
            const createdTimestamp = new Date(Number(position.createdTimestamp) * 1000)

            totalUserDeposits += depositAmount
            if (!latestTimestamp || createdTimestamp > latestTimestamp) {
              latestTimestamp = createdTimestamp
            }

            await this.db.savePositionSnapshot(
              account.id,
              chain as any,
              position.id,
              depositAmount,
              createdTimestamp,
              account.referralTimestamp
                ? new Date(Number(account.referralTimestamp) * 1000)
                : undefined,
            )
          }

          // Update user activity status with aggregated data
          if (totalUserDeposits > 0) {
            await this.db.updateUserActivityStatus(account.id, totalUserDeposits, latestTimestamp)
          }
        }
      }
    }
  }

  // Enhanced startup method with configuration-based scheduling and backfill
  async startScheduledProcessing(performBackfill: boolean = true): Promise<void> {
    console.log('Starting enhanced scheduled processing with hourly snapshots')

    // Run database migrations first
    console.log('Running database migrations...')
    await this.db.migrate()
    console.log('Database migrations completed')

    // Get configuration
    const config = await this.db.config.getConfig()
    console.log('Configuration loaded:', config)

    // Perform backfill if enabled and requested
    if (performBackfill && config.enableBackfill) {
      console.log('Starting historical data backfill using hourly snapshots...')
      try {
        await this.pointsService.backfillHistoricalPoints()
        console.log('Historical data backfill completed')
      } catch (error) {
        console.error('Error during backfill:', error)
        // Continue with regular processing even if backfill fails
      }
    }

    // Run initial processing
    console.log('Running initial hourly processing...')
    await this.processHourly()

    // Schedule recurring processing based on configuration
    const intervalMs = await this.db.config.getProcessingIntervalMs()
    console.log(`Scheduling processing every ${intervalMs / 1000 / 60} minutes`)

    this.processingInterval = setInterval(async () => {
      try {
        await this.processHourly()
      } catch (error) {
        console.error('Error in scheduled processing:', error)
      }
    }, intervalMs)
  }

  async stopScheduledProcessing(): Promise<void> {
    if (this.processingInterval) {
      clearInterval(this.processingInterval)
      this.processingInterval = undefined
      console.log('Scheduled processing stopped')
    }
  }

  // Method to manually trigger backfill
  async runBackfill(fromDate?: Date): Promise<void> {
    console.log('Starting manual backfill...')
    await this.pointsService.backfillHistoricalPoints(fromDate)
    console.log('Manual backfill completed')
  }

  // Method to get processing statistics
  async getProcessingStats(): Promise<{
    totalReferrers: number
    totalActiveUsers: number
    lastProcessingTime?: Date
    totalPointDistributions: number
    configuredInterval: number
  }> {
    const [referrers, config, lastCalculation, distributionsResult] = await Promise.all([
      this.db.getAllReferrerAccounts(),
      this.db.config.getConfig(),
      this.db.getLastCalculationTimestamp(),
      this.db.rawDb.query('SELECT COUNT(*) as count FROM point_distributions'),
    ])

    const activeUsersResult = await this.db.rawDb.query(
      'SELECT COUNT(*) as count FROM user_activity_status WHERE is_active = true',
    )

    return {
      totalReferrers: referrers.length,
      totalActiveUsers: parseInt(activeUsersResult.rows[0]?.count || '0'),
      lastProcessingTime: lastCalculation || undefined,
      totalPointDistributions: parseInt(distributionsResult.rows[0]?.count || '0'),
      configuredInterval: config.processingIntervalHours,
    }
  }
}
