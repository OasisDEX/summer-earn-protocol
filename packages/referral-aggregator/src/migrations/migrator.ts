import { readFileSync, readdirSync } from 'fs'
import { join } from 'path'
import { Pool } from 'pg'

export class Migrator {
  private pool: Pool

  constructor(pool: Pool) {
    this.pool = pool
  }

  async runMigrations(): Promise<void> {
    console.log('Starting database migrations...')

    // Ensure migrations table exists
    await this.ensureMigrationsTable()

    // Get all migration files
    const migrationsDir = join(__dirname)
    const migrationFiles = readdirSync(migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort()

    // Get already applied migrations
    const appliedMigrations = await this.getAppliedMigrations()

    // Apply pending migrations
    for (const file of migrationFiles) {
      if (!appliedMigrations.includes(file)) {
        await this.applyMigration(file)
      } else {
        console.log(`Migration ${file} already applied, skipping`)
      }
    }

    console.log('Database migrations completed')
  }

  private async ensureMigrationsTable(): Promise<void> {
    const query = `
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `
    await this.pool.query(query)
  }

  private async getAppliedMigrations(): Promise<string[]> {
    try {
      const result = await this.pool.query('SELECT filename FROM migrations ORDER BY applied_at')
      return result.rows.map((row) => row.filename)
    } catch (error) {
      // If migrations table doesn't exist yet, return empty array
      return []
    }
  }

  private async applyMigration(filename: string): Promise<void> {
    console.log(`Applying migration: ${filename}`)

    const migrationPath = join(__dirname, filename)
    const sql = readFileSync(migrationPath, 'utf8')

    const client = await this.pool.connect()
    try {
      await client.query('BEGIN')

      // Execute the migration SQL
      await client.query(sql)

      // Record the migration as applied
      await client.query('INSERT INTO migrations (filename) VALUES ($1)', [filename])

      await client.query('COMMIT')
      console.log(`Migration ${filename} applied successfully`)
    } catch (error) {
      await client.query('ROLLBACK')
      console.error(`Error applying migration ${filename}:`, error)
      throw error
    } finally {
      client.release()
    }
  }
}
