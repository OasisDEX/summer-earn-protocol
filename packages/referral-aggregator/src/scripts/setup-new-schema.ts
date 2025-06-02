#!/usr/bin/env ts-node

/**
 * Script to set up the new database schema
 *
 * Usage:
 *   npm run setup-new-schema        # Runs migration
 *   npm run setup-new-schema reset  # Resets and runs migration
 */

import { Pool } from 'pg'
import { KyselyMigrator } from '../migrations/kysely-migrator'

async function main() {
  const action = process.argv[2]

  const pool = new Pool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'referral_points',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  })

  const migrator = new KyselyMigrator(pool)

  try {
    if (action === 'reset') {
      console.log('🔄 Resetting database...')
      await migrator.reset()
    }

    console.log('🚀 Running migrations...')
    await migrator.runMigrations()

    console.log('✅ Database setup complete!')
    console.log('\n📝 Next steps:')
    console.log('1. Run "npm run codegen:kysely" to regenerate TypeScript types')
    console.log('2. Update the application code to use the new schema')
    console.log('3. Test the referral processing with the new structure')
  } catch (error) {
    console.error('❌ Setup failed:', error)
    process.exit(1)
  } finally {
    await migrator.close()
    await pool.end()
  }
}

main().catch(console.error)
