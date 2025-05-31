import { Kysely, PostgresDialect, sql } from 'kysely'
import { Pool } from 'pg'

export interface Migration {
  name: string
  up: (db: Kysely<any>) => Promise<void>
  down: (db: Kysely<any>) => Promise<void>
}

export class KyselyMigrator {
  private db: Kysely<any>
  private pool: Pool

  constructor(pool: Pool) {
    this.pool = pool
    this.db = new Kysely<any>({
      dialect: new PostgresDialect({
        pool: this.pool,
      }),
    })
  }

  async runMigrations(): Promise<void> {
    console.log('Starting Kysely database migrations...')

    // Ensure migrations table exists
    await this.ensureMigrationsTable()

    // Get all migrations
    const migrations = this.getMigrations()

    // Get already applied migrations
    const appliedMigrations = await this.getAppliedMigrations()

    // Apply pending migrations
    for (const migration of migrations) {
      if (!appliedMigrations.includes(migration.name)) {
        await this.applyMigration(migration)
      } else {
        console.log(`Migration ${migration.name} already applied, skipping`)
      }
    }

    console.log('Kysely database migrations completed')
  }

  async rollbackMigrations(): Promise<void> {
    console.log('Rolling back all migrations...')

    // Get applied migrations in reverse order
    const appliedMigrations = await this.getAppliedMigrations()
    const migrations = this.getMigrations()

    for (let i = appliedMigrations.length - 1; i >= 0; i--) {
      const migrationName = appliedMigrations[i]
      const migration = migrations.find((m) => m.name === migrationName)

      if (migration) {
        await this.rollbackMigration(migration)
      }
    }

    console.log('All migrations rolled back')
  }

  private async ensureMigrationsTable(): Promise<void> {
    await this.db.schema
      .createTable('migrations')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('filename', 'varchar(255)', (col) => col.notNull().unique())
      .addColumn('applied_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()
  }

  private async getAppliedMigrations(): Promise<string[]> {
    try {
      const result = await this.db
        .selectFrom('migrations')
        .select('filename')
        .orderBy('applied_at')
        .execute()

      return result.map((row) => row.filename)
    } catch (error) {
      // If migrations table doesn't exist yet, return empty array
      return []
    }
  }

  private async applyMigration(migration: Migration): Promise<void> {
    console.log(`Applying migration: ${migration.name}`)

    const client = await this.pool.connect()
    try {
      await client.query('BEGIN')

      // Execute the migration
      await migration.up(this.db)

      // Record the migration as applied
      await this.db.insertInto('migrations').values({ filename: migration.name }).execute()

      await client.query('COMMIT')
      console.log(`Migration ${migration.name} applied successfully`)
    } catch (error) {
      await client.query('ROLLBACK')
      console.error(`Error applying migration ${migration.name}:`, error)
      throw error
    } finally {
      client.release()
    }
  }

  private async rollbackMigration(migration: Migration): Promise<void> {
    console.log(`Rolling back migration: ${migration.name}`)

    const client = await this.pool.connect()
    try {
      await client.query('BEGIN')

      // Execute the rollback
      await migration.down(this.db)

      // Remove the migration record
      await this.db.deleteFrom('migrations').where('filename', '=', migration.name).execute()

      await client.query('COMMIT')
      console.log(`Migration ${migration.name} rolled back successfully`)
    } catch (error) {
      await client.query('ROLLBACK')
      console.error(`Error rolling back migration ${migration.name}:`, error)
      throw error
    } finally {
      client.release()
    }
  }

  private getMigrations(): Migration[] {
    return [
      {
        name: '001_simplified_referral_schema',
        up: this.migration001SimplifiedUp.bind(this),
        down: this.migration001SimplifiedDown.bind(this),
      },
    ]
  }

  // Simplified schema migration
  private async migration001SimplifiedUp(db: Kysely<any>): Promise<void> {
    // 1. Create referral_codes table (aggregated stats)
    await db.schema
      .createTable('referral_codes')
      .ifNotExists()
      .addColumn('id', 'varchar(100)', (col) => col.primaryKey())
      .addColumn('custom_code', 'varchar(100)', (col) => col.unique())
      // Running totals
      .addColumn('total_points', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('total_deposits_usd', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('active_users_count', 'integer', (col) => col.notNull().defaultTo(0))
      // Daily rates for frontend
      .addColumn('points_per_day', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('deposits_per_day', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      // Tracking
      .addColumn('last_calculated_at', 'timestamptz')
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('updated_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // 2. Create users table (simplified)
    await db.schema
      .createTable('users')
      .ifNotExists()
      .addColumn('id', 'varchar(100)', (col) => col.primaryKey())
      .addColumn('referrer_id', 'varchar(100)', (col) => 
        col.references('referral_codes.id').onDelete('set null')
      )
      .addColumn('referral_chain', 'varchar(20)')
      .addColumn('referral_timestamp', 'timestamptz')
      // User stats (running totals)
      .addColumn('total_deposits_usd', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('is_active', 'boolean', (col) => col.notNull().defaultTo(false))
      .addColumn('last_activity_at', 'timestamptz')
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('updated_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // 3. Create positions table (current state only - no snapshots!)
    await db.schema
      .createTable('positions')
      .ifNotExists()
      .addColumn('id', 'varchar(100)', (col) => col.notNull())
      .addColumn('chain', 'varchar(20)', (col) => col.notNull())
      .addColumn('user_id', 'varchar(100)', (col) => 
        col.notNull().references('users.id').onDelete('cascade')
      )
      .addColumn('current_deposit_usd', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('last_synced_at', 'timestamptz')
      .addPrimaryKeyConstraint('positions_pkey', ['id', 'chain'])
      .execute()

    // 4. Create processing checkpoint table
    await db.schema
      .createTable('processing_checkpoint')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('last_processed_timestamp', 'timestamptz', (col) => col.notNull())
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // 5. Create daily stats table (optional, for historical tracking)
    await db.schema
      .createTable('daily_stats')
      .ifNotExists()
      .addColumn('referral_id', 'varchar(100)', (col) => 
        col.notNull().references('referral_codes.id').onDelete('cascade')
      )
      .addColumn('date', 'date', (col) => col.notNull())
      .addColumn('points_earned', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('active_users', 'integer', (col) => col.notNull().defaultTo(0))
      .addColumn('total_deposits', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addPrimaryKeyConstraint('daily_stats_pkey', ['referral_id', 'date'])
      .execute()

    // 6. Create points_config table for configuration
    await db.schema
      .createTable('points_config')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('key', 'varchar(100)', (col) => col.notNull().unique())
      .addColumn('value', 'text', (col) => col.notNull())
      .addColumn('description', 'text')
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('updated_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // 7. Create points distribution table
    await db.schema
      .createTable('points_distributions')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('referral_id', 'varchar(100)', (col) => 
        col.notNull().references('referral_codes.id').onDelete('cascade')
      )
      .addColumn('points_amount', sql`decimal(20,8)`, (col) => col.notNull())
      .addColumn('description', 'text', (col) => col.notNull())
      .addColumn('distribution_timestamp', 'timestamptz', (col) => col.notNull().defaultTo(sql`NOW()`))
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // Add index for points_distributions
    await db.schema
      .createIndex('idx_points_distributions_referral_id')
      .ifNotExists()
      .on('points_distributions')
      .column('referral_id')
      .execute()

    await db.schema
      .createIndex('idx_points_distributions_timestamp')
      .ifNotExists()
      .on('points_distributions')
      .column('distribution_timestamp')
      .execute()

    // Create triggers to update updated_at columns
    await db.executeQuery(
      sql`
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = NOW();
          RETURN NEW;
      END;
      $$ language 'plpgsql';
    `.compile(db),
    )

    // Apply triggers to tables with updated_at
    const tablesWithUpdatedAt = ['referral_codes', 'users', 'points_config']
    for (const table of tablesWithUpdatedAt) {
      await db.executeQuery(
        sql`
        CREATE TRIGGER update_${sql.raw(table)}_updated_at BEFORE UPDATE ON ${sql.raw(table)}
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
      `.compile(db),
      )
    }

    // Create indexes for performance
    await this.createSimplifiedIndexes(db)

    // Insert default configuration
    await db
      .insertInto('points_config')
      .values([
        {
          key: 'processing_interval_hours',
          value: '1',
          description: 'How often points processing runs (in hours)',
        },
        {
          key: 'active_user_threshold_usd',
          value: '0.1',
          description: 'Minimum USD deposit amount to consider user active',
        },
        {
          key: 'points_formula_base',
          value: '0.00005',
          description: 'Base multiplier in points formula',
        },
        {
          key: 'points_formula_log_multiplier',
          value: '0.0005',
          description: 'Logarithmic multiplier in points formula',
        },
      ])
      .onConflict((oc) => oc.column('key').doNothing())
      .execute()
  }

  private async createSimplifiedIndexes(db: Kysely<any>): Promise<void> {
    // Referral codes indexes
    await db.schema
      .createIndex('idx_referral_codes_custom_code')
      .ifNotExists()
      .on('referral_codes')
      .column('custom_code')
      .execute()

    // Users indexes
    await db.schema
      .createIndex('idx_users_referrer_id')
      .ifNotExists()
      .on('users')
      .column('referrer_id')
      .execute()

    await db.schema
      .createIndex('idx_users_is_active')
      .ifNotExists()
      .on('users')
      .column('is_active')
      .execute()

    // Positions indexes
    await db.schema
      .createIndex('idx_positions_user_id')
      .ifNotExists()
      .on('positions')
      .column('user_id')
      .execute()

    await db.schema
      .createIndex('idx_positions_chain')
      .ifNotExists()
      .on('positions')
      .column('chain')
      .execute()

    // Processing checkpoint index
    await db.schema
      .createIndex('idx_processing_checkpoint_timestamp')
      .ifNotExists()
      .on('processing_checkpoint')
      .column('last_processed_timestamp')
      .execute()

    // Daily stats indexes
    await db.schema
      .createIndex('idx_daily_stats_referral_id')
      .ifNotExists()
      .on('daily_stats')
      .column('referral_id')
      .execute()

    await db.schema
      .createIndex('idx_daily_stats_date')
      .ifNotExists()
      .on('daily_stats')
      .column('date')
      .execute()
  }

  private async migration001SimplifiedDown(db: Kysely<any>): Promise<void> {
    // Drop tables in reverse order of dependencies
    await db.schema.dropTable('points_distributions').ifExists().execute()
    await db.schema.dropTable('daily_stats').ifExists().execute()
    await db.schema.dropTable('processing_checkpoint').ifExists().execute()
    await db.schema.dropTable('positions').ifExists().execute()
    await db.schema.dropTable('points_config').ifExists().execute()
    await db.schema.dropTable('users').ifExists().execute()
    await db.schema.dropTable('referral_codes').ifExists().execute()
    
    // Drop the trigger function
    await db.executeQuery(
      sql`DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;`.compile(db),
    )
  }

  async reset(): Promise<void> {
    console.log('🧹 Resetting database - dropping all tables...')

    const client = await this.pool.connect()
    try {
      await client.query('BEGIN')

      // Drop all tables (order matters due to foreign keys)
      const tablesToDrop = [
        'user_activity_status',
        'point_distributions',
        'position_snapshots',
        'positions',
        'points_config',
        'referral_points',
        'custom_referral_codes',
        'processing_checkpoint',
        'users',
        'referral_codes',
        'migrations',
      ]

      for (const table of tablesToDrop) {
        await client.query(`DROP TABLE IF EXISTS ${table} CASCADE`)
        console.log(`Dropped table: ${table}`)
      }

      // Drop the trigger function
      await client.query('DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE')

      await client.query('COMMIT')
      console.log('✅ Database reset completed')
    } catch (error) {
      await client.query('ROLLBACK')
      console.error('❌ Error resetting database:', error)
      throw error
    } finally {
      client.release()
    }
  }

  async close(): Promise<void> {
    await this.db.destroy()
  }
}
