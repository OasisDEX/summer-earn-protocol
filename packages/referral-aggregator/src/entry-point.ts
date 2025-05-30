#!/usr/bin/env node

import { Logger, ProcessorConfig, ReferralProcessor } from './processor'

export interface EntryPointConfig extends ProcessorConfig {
  operation: 'process' | 'backfill' | 'stats'
  backfillFromDate?: string | Date
}

/**
 * Main entry point for all referral aggregator operations
 * Can be used from CLI or Lambda
 */
export async function execute(config?: Partial<EntryPointConfig>): Promise<{
  success: boolean
  data?: any
  error?: Error
}> {
  const operation = config?.operation || 'process'
  const logger = config?.logger || console

  const processor = new ReferralProcessor({ logger })

  try {
    switch (operation) {
      case 'process':
        logger.log('🚀 Starting referral points processing...')
        const processResult = await processor.processLatest()

        if (processResult.success) {
          logger.log('✅ Processing completed successfully!')
          logger.log(`   Points Distributed: ${processResult.pointsDistributed.toFixed(8)}`)
          logger.log(`   Users Processed: ${processResult.usersProcessed}`)
          logger.log(`   Active Users: ${processResult.activeUsers}`)
        }

        return {
          success: processResult.success,
          data: processResult,
          error: processResult.error,
        }

      case 'backfill':
        logger.log('🔄 Starting backfill operation...')

        let fromDate: Date | undefined
        if (config?.backfillFromDate) {
          if (config.backfillFromDate instanceof Date) {
            fromDate = config.backfillFromDate
          } else if (config.backfillFromDate === '--from-beginning') {
            fromDate = undefined
          } else {
            fromDate = new Date(config.backfillFromDate)
            if (isNaN(fromDate.getTime())) {
              throw new Error('Invalid date format. Use YYYY-MM-DD or --from-beginning')
            }
          }
        }

        const backfillResult = await processor.backfill(fromDate)

        if (backfillResult.success) {
          logger.log('✅ Backfill completed successfully!')
          logger.log(`   Total Points Distributed: ${backfillResult.pointsDistributed.toFixed(8)}`)
          logger.log(`   Total Users Processed: ${backfillResult.usersProcessed}`)
          logger.log(`   Total Active Users: ${backfillResult.activeUsers}`)
          logger.log(
            `   Period: ${backfillResult.periodStart.toISOString()} → ${backfillResult.periodEnd.toISOString()}`,
          )
        }

        return {
          success: backfillResult.success,
          data: backfillResult,
          error: backfillResult.error,
        }

      case 'stats':
        logger.log('📊 Fetching statistics...')
        const stats = await processor.getStats()

        logger.log('\n=== Referral Aggregator Statistics ===')
        logger.log(
          `Last Execution: ${stats.lastExecution ? stats.lastExecution.toISOString() : 'Never'}`,
        )
        logger.log(`Next Scheduled: ${stats.nextScheduledExecution.toISOString()}`)
        logger.log(`Hours Until Next: ${stats.hoursUntilNext.toFixed(2)}`)
        logger.log(`\nDatabase Statistics:`)
        logger.log(`  Total Referrers: ${stats.totalReferrers}`)
        logger.log(`  Total Active Users: ${stats.totalActiveUsers}`)
        logger.log(`  Total Point Distributions: ${stats.totalPointDistributions}`)

        if (stats.topReferrers.length > 0) {
          logger.log(`\nTop Referrers:`)
          stats.topReferrers.forEach((referrer, index) => {
            logger.log(
              `  ${(index + 1).toString().padStart(2)}. ${referrer.accountId} - ` +
                `${referrer.points.toFixed(4)} points ` +
                `(${referrer.activeReferredUsers} active users, $${referrer.totalDepositsUsd.toFixed(2)})`,
            )
          })
        }

        return {
          success: true,
          data: stats,
        }

      default:
        throw new Error(`Unknown operation: ${operation}`)
    }
  } catch (error) {
    logger.error(`❌ Operation failed:`, error)
    return {
      success: false,
      error: error as Error,
    }
  } finally {
    await processor.close()
  }
}

/**
 * Lambda handler
 */
export async function handler(event: any, context: any): Promise<any> {
  // Parse operation from event
  const operation = event.operation || 'process'
  const backfillFromDate = event.backfillFromDate

  // Create a logger that works with Lambda
  const lambdaLogger: Logger = {
    log: (...args: any[]) => console.log(...args),
    error: (...args: any[]) => console.error(...args),
    warn: (...args: any[]) => console.warn(...args),
  }

  const result = await execute({
    operation,
    backfillFromDate,
    logger: lambdaLogger,
  })

  return {
    statusCode: result.success ? 200 : 500,
    body: JSON.stringify(result),
  }
}

// CLI execution
if (require.main === module) {
  const args = process.argv.slice(2)

  function showUsage() {
    console.log('Referral Aggregator - Entry Point')
    console.log('=================================')
    console.log('')
    console.log('Usage:')
    console.log('  npm run execute                         # Process latest (default)')
    console.log('  npm run execute process                 # Process latest')
    console.log('  npm run execute backfill                # Backfill from earliest')
    console.log('  npm run execute backfill 2024-01-01     # Backfill from date')
    console.log('  npm run execute backfill --from-beginning # Backfill from beginning')
    console.log('  npm run execute stats                   # Show statistics')
    console.log('  npm run execute --help                  # Show help')
    console.log('')
    console.log('Description:')
    console.log('  Single entry point for all referral aggregator operations.')
    console.log('  Designed to work both as CLI tool and Lambda function.')
  }

  if (args.includes('--help') || args.includes('-h')) {
    showUsage()
    process.exit(0)
  }

  let operation: 'process' | 'backfill' | 'stats' = 'process'
  let backfillFromDate: string | undefined

  if (args[0] === 'process' || args[0] === 'backfill' || args[0] === 'stats') {
    operation = args[0]
    if (operation === 'backfill' && args[1]) {
      backfillFromDate = args[1]
    }
  }

  execute({ operation, backfillFromDate }).then((result) => {
    process.exit(result.success ? 0 : 1)
  })
}
