import { ReferralClient } from './client'
import { PointsConfig } from './config'
import { DatabaseService } from './db'
import { Chain } from './types'

export class EnhancedReferralPointsService {
  constructor(
    private db: DatabaseService,
    private client: ReferralClient,
  ) {}

  async calculateHourlyPoints(periodStart: Date, periodEnd: Date): Promise<void> {
    console.log(
      `Calculating points for period: ${periodStart.toISOString()} to ${periodEnd.toISOString()}`,
    )

    const config = await this.db.config.getConfig()

    // Get all referral relationships with active user data
    const referralData = await this.db.getReferralRelationshipsWithActiveUsers()

    console.log(`Processing ${referralData.length} referrers`)

    for (const { referrerId, referredUsers } of referralData) {
      console.log(referrerId)
      console.log(referredUsers)
      await this.calculatePointsForReferrer(
        referrerId,
        referredUsers,
        config,
        periodStart,
        periodEnd,
      )
    }

    console.log('Hourly points calculation completed')
  }

  private async calculatePointsForReferrer(
    referrerId: string,
    referredUsers: Array<{
      referredId: string
      chain: Chain
      referralTimestamp: Date
      totalDepositsUsd: number
      isActive: boolean
    }>,
    config: PointsConfig,
    periodStart: Date,
    periodEnd: Date,
  ): Promise<void> {
    // Filter active users with minimum deposit threshold
    const activeUsers = referredUsers.filter(
      (user) => user.isActive && user.totalDepositsUsd >= config.activeUserThresholdUsd,
    )

    if (activeUsers.length === 0) {
      console.log(`Referrer ${referrerId}: No active users, skipping`)
      return
    }

    // Calculate total deposits from active referred users
    const totalDepositsUsd = activeUsers.reduce((sum, user) => sum + user.totalDepositsUsd, 0)

    // Apply the points formula: deposits * (base + log_multiplier * ln(active_users + 1))
    const pointsForHour =
      totalDepositsUsd *
      (config.pointsFormulaBase +
        config.pointsFormulaLogMultiplier * Math.log(activeUsers.length + 1))

    console.log(
      `Referrer ${referrerId}: ${activeUsers.length} active users, ` +
        `$${totalDepositsUsd.toFixed(2)} deposits, ${pointsForHour.toFixed(8)} points for hour`,
    )

    // Record the point distribution
    await this.db.recordPointDistribution(
      referrerId,
      referrerId, // referrer_id and account_id are the same for referrer points
      pointsForHour,
      totalDepositsUsd,
      activeUsers.length,
      periodStart,
      periodEnd,
    )
  }

  async backfillHistoricalPoints(fromDate?: Date): Promise<void> {
    const config = await this.db.config.getConfig()

    if (!config.enableBackfill) {
      console.log('Backfill is disabled in configuration')
      return
    }

    console.log('Starting historical points backfill...')

    // Determine start date for backfill
    const startDate = fromDate || (await this.getEarliestReferralDate())
    if (!startDate) {
      console.log('No referral data found, skipping backfill')
      return
    }

    const lastCalculation = await this.db.getLastCalculationTimestamp()
    const endDate = lastCalculation || new Date()

    console.log(`Backfilling from ${startDate.toISOString()} to ${endDate.toISOString()}`)

    // Process hour by hour
    let currentHour = new Date(startDate)
    currentHour.setMinutes(0, 0, 0) // Round to hour boundary

    const totalHours = Math.ceil((endDate.getTime() - currentHour.getTime()) / (1000 * 60 * 60))
    let processedHours = 0

    while (currentHour < endDate) {
      const nextHour = new Date(currentHour.getTime() + 60 * 60 * 1000)

      // Update user activity status for this period based on snapshots
      await this.updateUserActivityForPeriod(currentHour, nextHour)

      // Calculate points for this hour
      await this.calculateHourlyPoints(currentHour, nextHour)

      currentHour = nextHour
      processedHours++

      if (processedHours % 24 === 0) {
        console.log(
          `Backfill progress: ${processedHours}/${totalHours} hours (${((processedHours / totalHours) * 100).toFixed(1)}%)`,
        )
      }
    }

    console.log('Historical points backfill completed')
  }

  private async getEarliestReferralDate(): Promise<Date | null> {
    try {
      const query = `
        SELECT MIN(referral_timestamp) as earliest_referral
        FROM referral_relationships
      `
      const result = await this.db.rawDb.query(query)
      return result.rows[0]?.earliest_referral || null
    } catch (error) {
      console.error('Error getting earliest referral date:', error)
      return null
    }
  }

  private async updateUserActivityForPeriod(periodStart: Date, periodEnd: Date): Promise<void> {
    // Enhanced approach: Get actual hourly snapshots for this period
    const hourStart = Math.floor(periodStart.getTime() / 1000)
    const hourEnd = Math.floor(periodEnd.getTime() / 1000)

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

    console.log(
      `Updating activity status for ${result.rows.length} accounts in period ${periodStart.toISOString()} - ${periodEnd.toISOString()}`,
    )

    for (const row of result.rows) {
      await this.db.updateUserActivityStatus(
        row.account_id,
        Number(row.total_deposits),
        row.last_deposit,
      )
    }
  }

  // Method to get current points for an account
  async getPoints(accountId: string): Promise<{
    points: number
    totalDepositsUsd: number
    activeReferredUsers: number
    lastUpdated: Date
    totalPointDistributions: number
  } | null> {
    const result = await this.db.getReferralPoints(accountId)
    if (!result) return null

    // Get total point distributions
    const distributionsQuery = `
      SELECT COALESCE(SUM(points_awarded), 0) as total_distributions
      FROM point_distributions
      WHERE account_id = $1
    `

    const distResult = await this.db.rawDb.query(distributionsQuery, [accountId])
    const totalDistributions = Number(distResult.rows[0]?.total_distributions || 0)

    return {
      ...result,
      totalPointDistributions: totalDistributions,
    }
  }

  // Method to get point distribution history
  async getPointDistributionHistory(
    accountId: string,
    fromDate?: Date,
    toDate?: Date,
  ): Promise<
    Array<{
      pointsAwarded: number
      totalDepositsUsd: number
      activeReferredUsers: number
      calculationTimestamp: Date
      periodStart: Date
      periodEnd: Date
    }>
  > {
    let query = `
      SELECT points_awarded, total_deposits_usd, active_referred_users,
             calculation_timestamp, period_start, period_end
      FROM point_distributions
      WHERE account_id = $1
    `

    const params: any[] = [accountId]

    if (fromDate) {
      query += ` AND period_start >= $${params.length + 1}`
      params.push(fromDate)
    }

    if (toDate) {
      query += ` AND period_end <= $${params.length + 1}`
      params.push(toDate)
    }

    query += ` ORDER BY calculation_timestamp DESC`

    const result = await this.db.rawDb.query(query, params)

    return result.rows.map((row) => ({
      pointsAwarded: Number(row.points_awarded),
      totalDepositsUsd: Number(row.total_deposits_usd),
      activeReferredUsers: row.active_referred_users,
      calculationTimestamp: row.calculation_timestamp,
      periodStart: row.period_start,
      periodEnd: row.period_end,
    }))
  }

  // Method to get all accounts with points (enhanced)
  async getAllAccountsWithPoints(): Promise<
    Array<{
      accountId: string
      points: number
      totalDepositsUsd: number
      activeReferredUsers: number
      lastUpdated: Date
      totalPointDistributions: number
      lastCalculationTimestamp?: Date
    }>
  > {
    const query = `
      SELECT 
        rp.account_id, 
        rp.points, 
        rp.total_deposits_usd, 
        rp.active_referred_users, 
        rp.last_updated,
        rp.last_calculation_timestamp,
        COALESCE(rp.total_point_distributions, 0) as total_point_distributions
      FROM referral_points rp
      ORDER BY rp.points DESC
    `

    const result = await this.db.rawDb.query(query)

    return result.rows.map((row: any) => ({
      accountId: row.account_id,
      points: Number(row.points),
      totalDepositsUsd: Number(row.total_deposits_usd),
      activeReferredUsers: row.active_referred_users,
      lastUpdated: row.last_updated,
      totalPointDistributions: Number(row.total_point_distributions),
      lastCalculationTimestamp: row.last_calculation_timestamp,
    }))
  }
}
