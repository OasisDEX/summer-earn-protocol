#!/usr/bin/env node

import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { EnhancedHourlyProcessor } from '../enhanced-hourly-processor'

async function runProcessor() {
  console.log('Starting Enhanced Referral Points Processor with Hourly Snapshots')
  console.log('='.repeat(70))

  const db = new DatabaseService()
  const client = new ReferralClient()
  const processor = new EnhancedHourlyProcessor(client, db)

  // Parse command line arguments
  const args = process.argv.slice(2)
  let performBackfill = true
  let showHelp = false

  for (const arg of args) {
    switch (arg) {
      case '--no-backfill':
        performBackfill = false
        break
      case '--help':
      case '-h':
        showHelp = true
        break
    }
  }

  if (showHelp) {
    showUsage()
    process.exit(0)
  }

  try {
    console.log('Configuration:')
    console.log(`  Backfill enabled: ${performBackfill}`)
    console.log(`  Using hourly snapshots for accurate balance data`)
    console.log('')

    // Setup graceful shutdown
    let isShuttingDown = false

    const gracefulShutdown = async (signal: string) => {
      if (isShuttingDown) return
      isShuttingDown = true

      console.log(`\nReceived ${signal}, starting graceful shutdown...`)

      try {
        await processor.stopScheduledProcessing()
        await db.close()
        console.log('Graceful shutdown completed')
        process.exit(0)
      } catch (error) {
        console.error('Error during shutdown:', error)
        process.exit(1)
      }
    }

    process.on('SIGINT', () => gracefulShutdown('SIGINT'))
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
    process.on('SIGUSR2', () => gracefulShutdown('SIGUSR2')) // nodemon

    // Start the enhanced processor with snapshot support
    await processor.startScheduledProcessing(performBackfill)

    console.log('')
    console.log('✅ Enhanced processor is running with hourly snapshot support!')
    console.log('Features enabled:')
    console.log('  - Hourly snapshot-based balance calculation')
    console.log('  - Historical backfill with accurate timestamp data')
    console.log('  - Configuration-driven processing intervals')
    console.log('  - Active user tracking with deposit thresholds')
    console.log('  - Point distribution history with timestamps')
    console.log('')
    console.log('Press Ctrl+C to stop gracefully')

    // Keep the process alive
    const keepAlive = setInterval(() => {
      // This interval keeps the process running
    }, 1000)

    // Cleanup on exit
    process.on('exit', () => {
      clearInterval(keepAlive)
    })
  } catch (error) {
    console.error('Fatal error:', error)
    await db.close()
    process.exit(1)
  }
}

function showUsage() {
  console.log('Enhanced Referral Points Processor with Hourly Snapshots')
  console.log('')
  console.log('Usage:')
  console.log('  npm run enhanced-processor-snapshots [options]')
  console.log('')
  console.log('Options:')
  console.log('  --no-backfill    Skip historical data backfill on startup')
  console.log('  --help, -h       Show this help message')
  console.log('')
  console.log('Features:')
  console.log('  • Uses hourly snapshots from subgraph for accurate balance data')
  console.log('  • Processes data for specific time periods (past hour for regular runs)')
  console.log('  • Historical backfill uses snapshots from specific time ranges')
  console.log('  • More accurate point calculations based on actual balance history')
  console.log('  • Configurable processing intervals and active user thresholds')
  console.log('')
  console.log('Examples:')
  console.log('  npm run enhanced-processor-snapshots')
  console.log('  npm run enhanced-processor-snapshots --no-backfill')
  console.log('')
  console.log('Environment Variables:')
  console.log('  DB_HOST           Database host (default: 127.0.0.1)')
  console.log('  DB_PORT           Database port (default: 5432)')
  console.log('  DB_NAME           Database name (default: referral_points)')
  console.log('  DB_USER           Database user (default: postgres)')
  console.log('  DB_PASSWORD       Database password (default: postgres)')
}

if (require.main === module) {
  runProcessor().catch((error) => {
    console.error('Unhandled error:', error)
    process.exit(1)
  })
}
