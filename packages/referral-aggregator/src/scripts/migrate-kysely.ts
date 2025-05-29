#!/usr/bin/env node

import { Pool } from 'pg'
import { KyselyMigrator } from '../migrations/kysely-migrator'

async function runMigration() {
  console.log('Kysely Migration Tool')
  console.log('====================')

  const pool = new Pool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'referral_points',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  })

  const migrator = new KyselyMigrator(pool)

  // Parse command line arguments
  const args = process.argv.slice(2)
  const command = args[0] || 'up'

  try {
    switch (command) {
      case 'up':
        console.log('Running migrations UP...')
        await migrator.runMigrations()
        console.log('✅ Migrations completed successfully!')
        break

      case 'down':
        console.log('Rolling back migrations...')
        await migrator.rollbackMigrations()
        console.log('✅ Rollback completed successfully!')
        break

      case 'reset':
        console.log('Resetting database (down + up)...')
        await migrator.rollbackMigrations()
        await migrator.runMigrations()
        console.log('✅ Database reset completed successfully!')
        break

      case '--help':
      case '-h':
        showUsage()
        break

      default:
        console.error(`Unknown command: ${command}`)
        showUsage()
        process.exit(1)
    }
  } catch (error) {
    console.error('❌ Migration error:', error)
    process.exit(1)
  } finally {
    await migrator.close()
  }
}

function showUsage() {
  console.log('')
  console.log('Usage:')
  console.log('  npm run migrate-kysely [command]')
  console.log('')
  console.log('Commands:')
  console.log('  up      Run pending migrations (default)')
  console.log('  down    Rollback all migrations')
  console.log('  reset   Rollback all migrations, then run them again')
  console.log('  --help  Show this help message')
  console.log('')
  console.log('Examples:')
  console.log('  npm run migrate-kysely up')
  console.log('  npm run migrate-kysely down')
  console.log('  npm run migrate-kysely reset')
  console.log('')
  console.log('Environment Variables:')
  console.log('  DB_HOST           Database host (default: 127.0.0.1)')
  console.log('  DB_PORT           Database port (default: 5432)')
  console.log('  DB_NAME           Database name (default: referral_points)')
  console.log('  DB_USER           Database user (default: postgres)')
  console.log('  DB_PASSWORD       Database password (default: postgres)')
  console.log('')
  console.log('Features:')
  console.log('  • Single consolidated migration with all tables')
  console.log('  • Type-safe Kysely schema definitions')
  console.log('  • Automatic index creation')
  console.log('  • Default configuration insertion')
  console.log('  • Complete rollback support')
}

if (require.main === module) {
  runMigration().catch((error) => {
    console.error('Unhandled error:', error)
    process.exit(1)
  })
}
