#!/usr/bin/env node

import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { EnhancedReferralPointsService } from '../enhanced-points'

async function runBackfill() {
  console.log('Starting referral points backfill script...')

  const db = new DatabaseService()
  const client = new ReferralClient()
  const pointsService = new EnhancedReferralPointsService(db, client)

  try {
    // Run migrations first
    console.log('Running database migrations...')
    await db.migrate()

    // Get command line arguments
    const args = process.argv.slice(2)
    let fromDate: Date | undefined

    if (args.length > 0) {
      const dateArg = args[0]
      if (dateArg === '--from-beginning') {
        // Start from the very beginning
        fromDate = undefined
      } else {
        // Parse specific date
        fromDate = new Date(dateArg)
        if (isNaN(fromDate.getTime())) {
          console.error('Invalid date format. Use YYYY-MM-DD or --from-beginning')
          process.exit(1)
        }
      }
    }

    // Check configuration
    const config = await db.config.getConfig()
    if (!config.enableBackfill) {
      console.log(
        'Backfill is disabled in configuration. Enable it by setting enable_backfill to true.',
      )
      process.exit(1)
    }

    console.log('Configuration:')
    console.log(`  Processing interval: ${config.processingIntervalHours} hours`)
    console.log(`  Active user threshold: $${config.activeUserThresholdUsd}`)
    console.log(`  Points formula base: ${config.pointsFormulaBase}`)
    console.log(`  Points formula log multiplier: ${config.pointsFormulaLogMultiplier}`)
    console.log('')

    // Display current statistics before backfill
    const statsBefore = await getStats(db)
    console.log('Statistics before backfill:')
    console.log(`  Total referrers: ${statsBefore.totalReferrers}`)
    console.log(`  Total active users: ${statsBefore.totalActiveUsers}`)
    console.log(`  Total point distributions: ${statsBefore.totalPointDistributions}`)
    console.log(`  Last calculation: ${statsBefore.lastCalculation || 'Never'}`)
    console.log('')

    // Run backfill
    const startTime = Date.now()
    await pointsService.backfillHistoricalPoints(fromDate)
    const endTime = Date.now()

    // Display statistics after backfill
    const statsAfter = await getStats(db)
    console.log('')
    console.log('Statistics after backfill:')
    console.log(`  Total referrers: ${statsAfter.totalReferrers}`)
    console.log(`  Total active users: ${statsAfter.totalActiveUsers}`)
    console.log(`  Total point distributions: ${statsAfter.totalPointDistributions}`)
    console.log(`  Last calculation: ${statsAfter.lastCalculation || 'Never'}`)
    console.log('')
    console.log(`Backfill completed in ${((endTime - startTime) / 1000).toFixed(2)} seconds`)

    // Show top referrers
    await showTopReferrers(pointsService)
  } catch (error) {
    console.error('Error during backfill:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

async function getStats(db: DatabaseService) {
  const [referrersResult, activeUsersResult, distributionsResult, lastCalculation] =
    await Promise.all([
      db.rawDb.query('SELECT COUNT(DISTINCT referrer_id) as count FROM referral_relationships'),
      db.rawDb.query('SELECT COUNT(*) as count FROM user_activity_status WHERE is_active = true'),
      db.rawDb.query('SELECT COUNT(*) as count FROM point_distributions'),
      db.getLastCalculationTimestamp(),
    ])

  return {
    totalReferrers: parseInt(referrersResult.rows[0]?.count || '0'),
    totalActiveUsers: parseInt(activeUsersResult.rows[0]?.count || '0'),
    totalPointDistributions: parseInt(distributionsResult.rows[0]?.count || '0'),
    lastCalculation: lastCalculation,
  }
}

async function showTopReferrers(pointsService: EnhancedReferralPointsService) {
  console.log('Top 10 referrers by points:')
  const accounts = await pointsService.getAllAccountsWithPoints()

  accounts.slice(0, 10).forEach((account, index) => {
    console.log(
      `${(index + 1).toString().padStart(2)}. ${account.accountId} - ` +
        `${account.points.toFixed(4)} points ` +
        `(${account.activeReferredUsers} active users, $${account.totalDepositsUsd.toFixed(2)})`,
    )
  })
}

// Add usage information
function showUsage() {
  console.log('Usage:')
  console.log('  npm run backfill                    # Backfill from earliest referral')
  console.log('  npm run backfill --from-beginning   # Same as above')
  console.log('  npm run backfill 2024-01-01         # Backfill from specific date')
  console.log('')
  console.log('Examples:')
  console.log('  npm run backfill 2024-01-01')
  console.log('  npm run backfill 2024-03-15')
}

if (require.main === module) {
  // Check for help flag
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    showUsage()
    process.exit(0)
  }

  runBackfill().catch((error) => {
    console.error('Unhandled error:', error)
    process.exit(1)
  })
}
