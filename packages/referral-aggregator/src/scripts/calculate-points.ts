import { DatabaseService } from '../db'
import { ReferralClient } from '../client'
import { ReferralPointsService } from '../points'

async function main() {
  const db = new DatabaseService()
  const client = new ReferralClient()
  const service = new ReferralPointsService(db, client)

  try {
    // Take snapshots of all positions
    console.log('Taking snapshots of all positions...')
    await service.snapshotAllPositions()
    console.log('Snapshots completed')

    // Calculate points for all accounts
    console.log('Calculating points for all accounts...')
    await service.updateAllPoints()
    console.log('Points calculation completed')
  } catch (error) {
    console.error('Error:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

main() 