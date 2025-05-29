#!/usr/bin/env node

import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { EnhancedHourlyProcessor } from '../enhanced-hourly-processor'
import { EnhancedReferralPointsService } from '../enhanced-points'

async function showStats() {
  console.log('Referral Points System Statistics')
  console.log('================================')

  const db = new DatabaseService()
  const client = new ReferralClient()
  const pointsService = new EnhancedReferralPointsService(db, client)
  const processor = new EnhancedHourlyProcessor(client, db)

  try {
    // Get configuration
    const config = await db.config.getConfig()
    console.log('\nConfiguration:')
    console.log(`  Processing interval: ${config.processingIntervalHours} hours`)
    console.log(`  Active user threshold: $${config.activeUserThresholdUsd}`)
    console.log(`  Points formula base: ${config.pointsFormulaBase}`)
    console.log(`  Points formula log multiplier: ${config.pointsFormulaLogMultiplier}`)
    console.log(`  Backfill enabled: ${config.enableBackfill}`)

    // Get processing statistics
    const stats = await processor.getProcessingStats()
    console.log('\nProcessing Statistics:')
    console.log(`  Total referrers: ${stats.totalReferrers}`)
    console.log(`  Total active users: ${stats.totalActiveUsers}`)
    console.log(`  Total point distributions: ${stats.totalPointDistributions}`)
    console.log(`  Last processing time: ${stats.lastProcessingTime || 'Never'}`)
    console.log(`  Configured interval: ${stats.configuredInterval} hours`)

    // Get database statistics
    const dbStats = await getDatabaseStats(db)
    console.log('\nDatabase Statistics:')
    console.log(`  Total referral relationships: ${dbStats.totalRelationships}`)
    console.log(`  Total position snapshots: ${dbStats.totalSnapshots}`)
    console.log(`  Total users tracked: ${dbStats.totalUsers}`)
    console.log(`  Users with $100+: ${dbStats.usersOver100}`)

    // Get top referrers
    console.log('\nTop 10 Referrers:')
    const accounts = await pointsService.getAllAccountsWithPoints()

    if (accounts.length === 0) {
      console.log('  No referrers found with points yet.')
    } else {
      accounts.slice(0, 10).forEach((account, index) => {
        console.log(
          `  ${(index + 1).toString().padStart(2)}. ${account.accountId.substring(0, 10)}... - ` +
            `${account.points.toFixed(4)} points ` +
            `(${account.activeReferredUsers} active, $${account.totalDepositsUsd.toFixed(2)})`,
        )
      })
    }

    // Get recent activity
    await showRecentActivity(db)
  } catch (error) {
    console.error('Error retrieving statistics:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

async function getDatabaseStats(db: DatabaseService) {
  const queries = [
    'SELECT COUNT(*) as count FROM referral_relationships',
    'SELECT COUNT(*) as count FROM position_snapshots',
    'SELECT COUNT(*) as count FROM user_activity_status',
    'SELECT COUNT(*) as count FROM user_activity_status WHERE total_deposits_usd >= 100',
  ]

  const results = await Promise.all(queries.map((query) => db.rawDb.query(query)))

  return {
    totalRelationships: parseInt(results[0].rows[0]?.count || '0'),
    totalSnapshots: parseInt(results[1].rows[0]?.count || '0'),
    totalUsers: parseInt(results[2].rows[0]?.count || '0'),
    usersOver100: parseInt(results[3].rows[0]?.count || '0'),
  }
}

async function showRecentActivity(db: DatabaseService) {
  console.log('\nRecent Activity (Last 24 Hours):')

  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000)

  // Recent point distributions
  const recentDistributions = await db.rawDb.query(
    `
    SELECT COUNT(*) as count, SUM(points_awarded) as total_points
    FROM point_distributions
    WHERE created_at >= $1
  `,
    [yesterday],
  )

  // Recent snapshots
  const recentSnapshots = await db.rawDb.query(
    `
    SELECT COUNT(*) as count, SUM(deposit_amount_usd) as total_deposits
    FROM position_snapshots
    WHERE snapshot_timestamp >= $1
  `,
    [yesterday],
  )

  // Recent referrals
  const recentReferrals = await db.rawDb.query(
    `
    SELECT COUNT(*) as count
    FROM referral_relationships
    WHERE created_at >= $1
  `,
    [yesterday],
  )

  const distCount = parseInt(recentDistributions.rows[0]?.count || '0')
  const totalPoints = Number(recentDistributions.rows[0]?.total_points || 0)
  const snapshotCount = parseInt(recentSnapshots.rows[0]?.count || '0')
  const totalDeposits = Number(recentSnapshots.rows[0]?.total_deposits || 0)
  const referralCount = parseInt(recentReferrals.rows[0]?.count || '0')

  console.log(`  Point distributions: ${distCount} (${totalPoints.toFixed(4)} total points)`)
  console.log(
    `  Position snapshots: ${snapshotCount} ($${totalDeposits.toFixed(2)} total deposits)`,
  )
  console.log(`  New referrals: ${referralCount}`)

  if (distCount === 0 && snapshotCount === 0 && referralCount === 0) {
    console.log('  No recent activity detected.')
  }
}

// Parse command line arguments for specific account details
async function showAccountDetails(
  accountId: string,
  db: DatabaseService,
  pointsService: EnhancedReferralPointsService,
) {
  console.log(`\nAccount Details: ${accountId}`)
  console.log('='.repeat(50))

  // Get points information
  const points = await pointsService.getPoints(accountId)
  if (points) {
    console.log(`Points: ${points.points.toFixed(4)}`)
    console.log(`Total deposits: $${points.totalDepositsUsd.toFixed(2)}`)
    console.log(`Active referred users: ${points.activeReferredUsers}`)
    console.log(`Last updated: ${points.lastUpdated}`)
    console.log(`Total distributions: ${points.totalPointDistributions.toFixed(4)}`)
  } else {
    console.log('No points data found for this account.')
  }

  // Get distribution history
  const history = await pointsService.getPointDistributionHistory(accountId)
  if (history.length > 0) {
    console.log('\nRecent Distributions (Last 10):')
    history.slice(0, 10).forEach((dist, index) => {
      console.log(
        `  ${index + 1}. ${dist.calculationTimestamp.toISOString().split('T')[0]} - ` +
          `${dist.pointsAwarded.toFixed(4)} points ` +
          `(${dist.activeReferredUsers} users, $${dist.totalDepositsUsd.toFixed(2)})`,
      )
    })
  }
}

function showUsage() {
  console.log('Usage:')
  console.log('  npm run stats                    # Show general statistics')
  console.log('  npm run stats <account-id>       # Show specific account details')
  console.log('')
  console.log('Examples:')
  console.log('  npm run stats')
  console.log('  npm run stats 0x1234567890abcdef...')
}

if (require.main === module) {
  const args = process.argv.slice(2)

  // Check for help flag
  if (args.includes('--help') || args.includes('-h')) {
    showUsage()
    process.exit(0)
  }

  // Check if specific account requested
  if (args.length > 0) {
    const accountId = args[0]
    if (!/^0x[a-fA-F0-9]{40}$/.test(accountId)) {
      console.error('Invalid account ID format. Must be a valid Ethereum address.')
      process.exit(1)
    }

    // Show account-specific details
    const db = new DatabaseService()
    const client = new ReferralClient()
    const pointsService = new EnhancedReferralPointsService(db, client)

    showAccountDetails(accountId, db, pointsService)
      .then(() => db.close())
      .catch((error) => {
        console.error('Error:', error)
        db.close()
        process.exit(1)
      })
  } else {
    // Show general stats
    showStats().catch((error) => {
      console.error('Unhandled error:', error)
      process.exit(1)
    })
  }
}
