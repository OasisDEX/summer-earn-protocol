import { ReferralClient } from './client'
import { DatabaseService } from './db'
import { Chain } from './types'

export class ReferralPointsService {
  constructor(
    private db: DatabaseService,
    private client: ReferralClient,
  ) {}

  async calculatePoints(accountId: string): Promise<void> {
    // Get all referred users from database
    const referredUsers = await this.db.getReferredUsers(accountId)

    // Calculate points based on position snapshots in database
    const activeReferredUsers = new Set<string>()
    let totalDepositsUsd = 0

    for (const { referredId, chain, referralTimestamp } of referredUsers) {
      // Get position snapshots for the referred user from database
      const snapshots = await this.db.getPositionSnapshots(referredId, new Date(0))

      // Filter snapshots that were created after referral
      const validSnapshots = snapshots.filter((snapshot) => {
        return snapshot.createdTimestamp >= referralTimestamp
      })

      if (validSnapshots.length > 0) {
        activeReferredUsers.add(referredId)
        // Sum up the deposit amounts from valid snapshots
        totalDepositsUsd += validSnapshots.reduce(
          (sum, snapshot) => sum + parseFloat(snapshot.depositAmountUsd.toString()),
          0,
        )
      }
    }

    // Calculate points using the formula: total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1))
    const points = totalDepositsUsd * (0.00005 + 0.0005 * Math.log(activeReferredUsers.size + 1))

    console.log(`Account ${accountId}: ${activeReferredUsers.size} active referred users, $${Number(totalDepositsUsd).toFixed(2)} total deposits, ${Number(points).toFixed(8)} points`)

    // Update points in database
    await this.db.upsertReferralPoints(
      accountId,
      points,
      totalDepositsUsd,
      activeReferredUsers.size,
    )
  }

  async updateAllPoints(): Promise<void> {
    // Get all accounts that have referred users
    const referrerAccounts = await this.db.getAllReferrerAccounts()

    console.log(`Calculating points for ${referrerAccounts.length} accounts with referrals`)

    // Calculate points for each account
    for (const referrerId of referrerAccounts) {
      await this.calculatePoints(referrerId)
    }

    console.log('Points calculation completed for all accounts')
  }

  // Method to get current points for an account
  async getPoints(accountId: string): Promise<{
    points: number
    totalDepositsUsd: number
    activeReferredUsers: number
    lastUpdated: Date
  } | null> {
    return await this.db.getReferralPoints(accountId)
  }

  // Method to get all accounts with points
  async getAllAccountsWithPoints(): Promise<Array<{
    accountId: string
    points: number
    totalDepositsUsd: number
    activeReferredUsers: number
    lastUpdated: Date
  }>> {
    return await this.db.getAllAccountsWithPoints()
  }
}
