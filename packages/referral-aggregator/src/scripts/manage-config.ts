#!/usr/bin/env node

import { DatabaseService } from '../db'

async function manageConfig() {
  const db = new DatabaseService()
  const args = process.argv.slice(2)

  try {
    // Run migrations first to ensure config table exists
    await db.migrate()

    if (args.length === 0) {
      // Show current configuration
      await showConfig(db)
    } else if (args.length === 2) {
      // Update configuration
      const [key, value] = args
      await updateConfig(db, key, value)
    } else {
      showUsage()
      process.exit(1)
    }
  } catch (error) {
    console.error('Error managing configuration:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

async function showConfig(db: DatabaseService) {
  console.log('Current Configuration:')
  console.log('=====================')

  const config = await db.config.getConfig()

  console.log(`Processing interval: ${config.processingIntervalHours} hours`)
  console.log(`Active user threshold: $${config.activeUserThresholdUsd}`)
  console.log(`Points formula base: ${config.pointsFormulaBase}`)
  console.log(`Points formula log multiplier: ${config.pointsFormulaLogMultiplier}`)
  console.log(`Backfill enabled: ${config.enableBackfill}`)

  console.log('\nFormula: points = deposits * (base + log_multiplier * ln(active_users + 1))')
  console.log(
    `Current: points = deposits * (${config.pointsFormulaBase} + ${config.pointsFormulaLogMultiplier} * ln(active_users + 1))`,
  )
}

async function updateConfig(db: DatabaseService, key: string, value: string) {
  const validKeys = [
    'processing_interval_hours',
    'active_user_threshold_usd',
    'points_formula_base',
    'points_formula_log_multiplier',
    'enable_backfill',
  ]

  if (!validKeys.includes(key)) {
    console.error(`Invalid configuration key: ${key}`)
    console.error(`Valid keys: ${validKeys.join(', ')}`)
    process.exit(1)
  }

  // Validate values
  if (key === 'enable_backfill') {
    if (!['true', 'false'].includes(value.toLowerCase())) {
      console.error('enable_backfill must be "true" or "false"')
      process.exit(1)
    }
    value = value.toLowerCase()
  } else {
    const numValue = parseFloat(value)
    if (isNaN(numValue) || numValue < 0) {
      console.error(`${key} must be a positive number`)
      process.exit(1)
    }
  }

  await db.config.updateConfig(key, value)
  console.log(`Updated ${key} to ${value}`)

  // Show updated configuration
  console.log('')
  await showConfig(db)
}

function showUsage() {
  console.log('Configuration Management')
  console.log('=======================')
  console.log('')
  console.log('Usage:')
  console.log('  npm run config                                    # Show current config')
  console.log('  npm run config <key> <value>                     # Update config')
  console.log('')
  console.log('Available configuration keys:')
  console.log('  processing_interval_hours        # How often to run processing (hours)')
  console.log('  active_user_threshold_usd        # Minimum USD to be considered active')
  console.log('  points_formula_base              # Base multiplier in formula')
  console.log('  points_formula_log_multiplier    # Logarithmic multiplier in formula')
  console.log('  enable_backfill                  # Enable/disable backfill (true/false)')
  console.log('')
  console.log('Examples:')
  console.log('  npm run config processing_interval_hours 2')
  console.log('  npm run config active_user_threshold_usd 50')
  console.log('  npm run config points_formula_base 0.0001')
  console.log('  npm run config enable_backfill false')
}

if (require.main === module) {
  // Check for help flag
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    showUsage()
    process.exit(0)
  }

  manageConfig().catch((error) => {
    console.error('Unhandled error:', error)
    process.exit(1)
  })
}
