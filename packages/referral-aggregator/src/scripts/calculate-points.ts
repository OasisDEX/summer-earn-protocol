import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { ReferralPointsService } from '../points'

async function main() {
  const db = new DatabaseService()
  const client = new ReferralClient()
  const service = new ReferralPointsService(db, client)

  try {
    console.log('Calculating points for all accounts...')
    console.log('Note: This uses data already collected by the hourly processor')
    
    // Calculate points for all accounts based on existing database data
    await service.updateAllPoints()
    
    // Display results
    console.log('\n--- Points Summary ---')
    const accountsWithPoints = await service.getAllAccountsWithPoints()
    
    if (accountsWithPoints.length === 0) {
      console.log('No accounts with points found. Make sure the hourly processor has run first.')
    } else {
      console.log(`Found ${accountsWithPoints.length} accounts with points:`)
      for (const account of accountsWithPoints) {
        console.log(`${account.accountId}: ${account.points.toFixed(8)} points (${account.activeReferredUsers} referred users, $${account.totalDepositsUsd.toFixed(2)} deposits)`)
      }
    }
    
    console.log('\nPoints calculation completed')
  } catch (error) {
    console.error('Error:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

main()
