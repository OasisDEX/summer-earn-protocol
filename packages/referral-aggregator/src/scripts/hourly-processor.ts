import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { HourlyProcessor } from '../hourly-processor'

async function main() {
  const db = new DatabaseService()
  const client = new ReferralClient()
  const processor = new HourlyProcessor(client, db)

  try {
    console.log('Starting hourly processor...')
    await processor.startScheduledProcessing()
  } catch (error) {
    console.error('Error in hourly processor:', error)
    process.exit(1)
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully...')
  process.exit(0)
})

process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...')
  process.exit(0)
})

main()
