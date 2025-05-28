import { DatabaseService } from './db'
import { ReferralClient } from './client'
import { Chain } from './types'

export class ReferralPointsService {
  constructor(
    private db: DatabaseService,
    private client: ReferralClient
  ) {}

  async calculatePoints(accountId: string): Promise<void> {
    // Get all referred users
    const referredUsers = await this.db.getReferredUsers(accountId)
    
    // Get positions for each referred user
    const activeReferredUsers = new Set<string>()
    let totalDepositsUsd = 0

    for (const { referredId, chain, referralTimestamp } of referredUsers) {
      // Get positions for the referred user
      const positions = await this.client.getPositions(referredId, chain)
      
      // Filter positions that were created after referral
      const validPositions = positions.filter(position => {
        const positionCreatedAt = new Date(Number(position.createdAt) * 1000)
        return positionCreatedAt >= referralTimestamp
      })

      if (validPositions.length > 0) {
        activeReferredUsers.add(referredId)
        totalDepositsUsd += validPositions.reduce((sum, pos) => sum + Number(pos.depositAmountUsd), 0)
      }
    }

    // Calculate points using the formula: total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1))
    const points = totalDepositsUsd * (0.00005 + 0.0005 * Math.log(activeReferredUsers.size + 1))

    // Update points in database
    await this.db.upsertReferralPoints(
      accountId,
      points,
      totalDepositsUsd,
      activeReferredUsers.size
    )
  }

  async updateAllPoints(): Promise<void> {
    // Get all accounts with referral points
    const query = 'SELECT DISTINCT account_id FROM referral_points'
    const result = await this.db.pool.query(query)
    
    // Calculate points for each account
    for (const { account_id } of result.rows) {
      await this.calculatePoints(account_id)
    }
  }

  async snapshotPositions(accountId: string, chain: Chain): Promise<void> {
    const positions = await this.client.getPositions(accountId, chain)
    const account = await this.client.getAccount(accountId, chain)

    for (const position of positions) {
      await this.db.savePositionSnapshot(
        accountId,
        chain,
        position.id,
        Number(position.depositAmountUsd),
        new Date(Number(position.createdAt) * 1000),
        account?.referralData?.timestamp ? new Date(Number(account.referralData.timestamp) * 1000) : undefined
      )
    }
  }

  async snapshotAllPositions(): Promise<void> {
    const chains: Chain[] = ['Ethereum', 'Polygon', 'Arbitrum', 'Base']
    
    // Get all accounts with referral points
    const query = 'SELECT DISTINCT account_id FROM referral_points'
    const result = await this.db.pool.query(query)
    
    // Snapshot positions for each account on each chain
    for (const { account_id } of result.rows) {
      for (const chain of chains) {
        await this.snapshotPositions(account_id, chain)
      }
    }
  }
} 