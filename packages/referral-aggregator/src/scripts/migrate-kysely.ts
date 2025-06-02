#!/usr/bin/env node

import { Pool } from 'pg'
import { KyselyMigrator } from '../migrations/kysely-migrator'

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'referral_points',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
  })

  const migrator = new KyselyMigrator(pool)

  try {
    const command = process.argv[2]

    switch (command) {
      case 'reset':
        await migrator.reset()
        await migrator.runMigrations()
        break
      case 'up':
        await migrator.runMigrations()
        break
      case 'down':
        await migrator.rollbackMigrations()
        break
      default:
        await migrator.runMigrations()
        break
    }
  } catch (error) {
    console.error('Migration failed:', error)
    process.exit(1)
  } finally {
    await migrator.close()
    // await pool.end()
  }
}

main()
