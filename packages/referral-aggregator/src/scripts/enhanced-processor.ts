#!/usr/bin/env node

import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { EnhancedHourlyProcessor } from '../enhanced-hourly-processor'

async function startEnhancedProcessor() {
  console.log('Starting Enhanced Referral Points Processor...')

  const db = new DatabaseService()
  const client = new ReferralClient()
  const processor = new EnhancedHourlyProcessor(client, db)

  // Parse command line arguments
  const args = process.argv.slice(2)
  const skipBackfill = args.includes('--skip-backfill')
  const performBackfill = !skipBackfill

  try {
    console.log('Enhanced Referral Points Processor Configuration:')
    const config = await db.config.getConfig()
    console.log(`  Processing interval: ${config.processingIntervalHours} hours`)
    console.log(`  Active user threshold: $${config.activeUserThresholdUsd}`)
    console.log(`  Backfill enabled: ${config.enableBackfill}`)
    console.log(`  Perform backfill on startup: ${performBackfill}`)
    console.log('')

    // Start the processor
    await processor.startScheduledProcessing(performBackfill)

    console.log('Enhanced processor is now running. Press Ctrl+C to stop.')

    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      console.log('\nReceived SIGINT, shutting down gracefully...')
      await processor.stopScheduledProcessing()
      await db.close()
      console.log('Shutdown complete.')
      process.exit(0)
    })

    process.on('SIGTERM', async () => {
      console.log('\nReceived SIGTERM, shutting down gracefully...')
      await processor.stopScheduledProcessing()
      await db.close()
      console.log('Shutdown complete.')
      process.exit(0)
    })

    // Keep the process alive
    setInterval(() => {
      // Do nothing, just keep the process running
    }, 60000)
  } catch (error) {
    console.error('Error starting enhanced processor:', error)
    await db.close()
    process.exit(1)
  }
}

// Show usage information
function showUsage() {
  console.log('Usage:')
  console.log('  npm run enhanced-processor              # Start with backfill (if enabled)')
  console.log('  npm run enhanced-processor --skip-backfill  # Start without backfill')
  console.log('')
  console.log('The processor will:')
  console.log('  1. Run database migrations')
  console.log('  2. Optionally perform historical backfill')
  console.log('  3. Start hourly points calculation on configured schedule')
  console.log('  4. Continue running until stopped with Ctrl+C')
  console.log('')
  console.log('Configuration can be managed with:')
  console.log('  npm run config')
}

if (require.main === module) {
  // Check for help flag
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    showUsage()
    process.exit(0)
  }

  startEnhancedProcessor().catch((error) => {
    console.error('Unhandled error:', error)
    process.exit(1)
  })
}
