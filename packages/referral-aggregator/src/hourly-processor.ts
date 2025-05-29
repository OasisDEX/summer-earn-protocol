import { ReferralClient } from './client'
import { DatabaseService } from './db'
import { Account } from './types'

export class HourlyProcessor {
  constructor(
    private client: ReferralClient,
    private db: DatabaseService,
  ) {}

  async processHourly(): Promise<void> {
    const now = new Date()
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000)

    // Check if this is the first run by looking for any existing data
    const isFirstRun = await this.isFirstRun()

    console.log(`Starting hourly processing - First run: ${isFirstRun}`)

    // Step 1: Get all referred accounts with timestamp bounds
    const { validAccounts, allReferredAccounts } = await this.client.processReferredAccountsHourly(
      isFirstRun ? undefined : BigInt(Math.floor(oneHourAgo.getTime() / 1000)),
      BigInt(Math.floor(now.getTime() / 1000)),
      isFirstRun,
    )

    console.log(
      `Found ${allReferredAccounts.length} referred accounts, ${validAccounts.length} valid`,
    )

    if (validAccounts.length === 0) {
      console.log('No valid accounts found, skipping position processing')
      return
    }

    // Step 2: Get all positions for valid accounts
    const accountsWithPositions = await this.client.getAllPositionsForAccounts(validAccounts)

    // Step 3: Store the data in database
    await this.storeAccountsAndPositions(accountsWithPositions)

    console.log('Hourly processing completed')
  }

  private async isFirstRun(): Promise<boolean> {
    try {
      return !(await this.db.hasAnyData())
    } catch (error) {
      console.error('Error checking if first run:', error)
      return true // Assume first run on error
    }
  }

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

        // Store position snapshots
        if (account.positions) {
          for (const position of account.positions) {
            await this.db.savePositionSnapshot(
              account.id,
              chain as any,
              position.id,
              Number(position.inputTokenBalanceNormalizedInUSD || 0),
              new Date(Number(position.createdTimestamp) * 1000),
              account.referralTimestamp
                ? new Date(Number(account.referralTimestamp) * 1000)
                : undefined,
            )
          }
        }
      }
    }
  }

  // Method to run processing on a schedule
  async startScheduledProcessing(): Promise<void> {
    console.log('Starting scheduled hourly processing')

    // Run database migrations first
    console.log('Running database migrations...')
    await this.db.migrate()
    console.log('Database migrations completed')

    // Run immediately
    await this.processHourly()

    // Schedule to run every hour
    setInterval(
      async () => {
        try {
          await this.processHourly()
        } catch (error) {
          console.error('Error in scheduled processing:', error)
        }
      },
      60 * 60 * 1000,
    ) // 1 hour in milliseconds
  }
}
