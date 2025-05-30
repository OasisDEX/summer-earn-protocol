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
        name: '001_users_schema',
        up: this.migration001Up.bind(this),
        down: this.migration001Down.bind(this),
      },
    ]
  }

  // New clean migration with users table
  private async migration001Up(db: Kysely<any>): Promise<void> {
    // Create users table (replaces referral_relationships)
    await db.schema
      .createTable('users')
      .ifNotExists()
      .addColumn('id', 'varchar(100)', (col) => col.notNull()) // user address
      .addColumn('referral_chain', 'varchar(20)', (col) => col.notNull()) // chain where user exists
      .addColumn('referral_id', 'varchar(100)') // nullable - referral code of this user
      .addColumn('referrer_id', 'varchar(100)') // nullable - who referred this user
      .addColumn('referral_timestamp', 'timestamptz') // when they were referred
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('updated_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addPrimaryKeyConstraint('users_pkey', ['id', 'referral_chain']) // one user per chain
      .execute()

    // Create trigger to update updated_at column
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

    await db.executeQuery(
      sql`
      CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    `.compile(db),
    )

    // Create referral_points table
    await db.schema
      .createTable('referral_points')
      .ifNotExists()
      .addColumn('account_id', 'varchar(100)', (col) => col.primaryKey())
      .addColumn('points', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('total_deposits_usd', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('active_referred_users', 'integer', (col) => col.notNull().defaultTo(0))
      .addColumn('last_updated', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('last_calculation_timestamp', 'timestamptz')
      .addColumn('total_point_distributions', sql`decimal(20,8)`, (col) => col.defaultTo(0))
      .execute()

    // Create position_snapshots table
    await db.schema
      .createTable('position_snapshots')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('account_id', 'varchar(100)', (col) => col.notNull())
      .addColumn('chain', 'varchar(20)', (col) => col.notNull())
      .addColumn('position_id', 'varchar(100)', (col) => col.notNull())
      .addColumn('deposit_amount_usd', sql`decimal(20,8)`, (col) => col.notNull())
      .addColumn('created_timestamp', 'timestamptz', (col) => col.notNull())
      .addColumn('referral_timestamp', 'timestamptz')
      .addColumn('snapshot_timestamp', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addUniqueConstraint('position_snapshots_unique', ['account_id', 'chain', 'position_id'])
      .execute()

    // Create points_config table
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

    // Create point_distributions table
    await db.schema
      .createTable('point_distributions')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('account_id', 'varchar(100)', (col) => col.notNull())
      .addColumn('referrer_id', 'varchar(100)', (col) => col.notNull())
      .addColumn('points_awarded', sql`decimal(20,8)`, (col) => col.notNull())
      .addColumn('total_deposits_usd', sql`decimal(20,8)`, (col) => col.notNull())
      .addColumn('active_referred_users', 'integer', (col) => col.notNull())
      .addColumn('calculation_timestamp', 'timestamptz', (col) => col.notNull())
      .addColumn('period_start', 'timestamptz', (col) => col.notNull())
      .addColumn('period_end', 'timestamptz', (col) => col.notNull())
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addUniqueConstraint('point_distributions_unique', ['account_id', 'calculation_timestamp'])
      .execute()

    // Create user_activity_status table
    await db.schema
      .createTable('user_activity_status')
      .ifNotExists()
      .addColumn('account_id', 'varchar(100)', (col) => col.primaryKey())
      .addColumn('total_deposits_usd', sql`decimal(20,8)`, (col) => col.notNull().defaultTo(0))
      .addColumn('is_active', 'boolean', (col) => col.notNull().defaultTo(false))
      .addColumn('last_deposit_timestamp', 'timestamptz')
      .addColumn('last_updated', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .execute()

    // Create custom_referral_codes table
    await db.schema
      .createTable('custom_referral_codes')
      .ifNotExists()
      .addColumn('id', 'serial', (col) => col.primaryKey())
      .addColumn('custom_code', 'varchar(100)', (col) => col.notNull().unique())
      .addColumn('actual_referrer_id', 'varchar(100)', (col) => col.notNull())
      .addColumn('referrer_address', 'varchar(100)', (col) => col.notNull())
      .addColumn('created_at', 'timestamptz', (col) => col.defaultTo(sql`NOW()`))
      .addColumn('is_active', 'boolean', (col) => col.notNull().defaultTo(true))
      .execute()

    // Create all indexes
    await this.createIndexes(db)

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
          value: '100',
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
        {
          key: 'enable_backfill',
          value: 'true',
          description: 'Whether to enable backfill processing on startup',
        },
      ])
      .onConflict((oc) => oc.column('key').doNothing())
      .execute()
  }

  private async createIndexes(db: Kysely<any>): Promise<void> {
    // Users table indexes
    await db.schema.createIndex('idx_users_id').ifNotExists().on('users').column('id').execute()

    await db.schema
      .createIndex('idx_users_referrer_id')
      .ifNotExists()
      .on('users')
      .column('referrer_id')
      .execute()

    await db.schema
      .createIndex('idx_users_chain')
      .ifNotExists()
      .on('users')
      .column('referral_chain')
      .execute()

    await db.schema
      .createIndex('idx_users_referral_timestamp')
      .ifNotExists()
      .on('users')
      .column('referral_timestamp')
      .execute()

    // Referral points indexes
    await db.schema
      .createIndex('idx_referral_points_account_id')
      .ifNotExists()
      .on('referral_points')
      .column('account_id')
      .execute()

    await db.schema
      .createIndex('idx_referral_points_last_calculation')
      .ifNotExists()
      .on('referral_points')
      .column('last_calculation_timestamp')
      .execute()

    // Position snapshots indexes
    await db.schema
      .createIndex('idx_position_snapshots_account_id')
      .ifNotExists()
      .on('position_snapshots')
      .column('account_id')
      .execute()

    await db.schema
      .createIndex('idx_position_snapshots_chain')
      .ifNotExists()
      .on('position_snapshots')
      .column('chain')
      .execute()

    await db.schema
      .createIndex('idx_position_snapshots_created_timestamp')
      .ifNotExists()
      .on('position_snapshots')
      .column('created_timestamp')
      .execute()

    await db.schema
      .createIndex('idx_position_snapshots_snapshot_timestamp')
      .ifNotExists()
      .on('position_snapshots')
      .column('snapshot_timestamp')
      .execute()

    await db.schema
      .createIndex('idx_position_snapshots_account_time')
      .ifNotExists()
      .on('position_snapshots')
      .columns(['account_id', 'snapshot_timestamp'])
      .execute()

    // Points config indexes
    await db.schema
      .createIndex('idx_points_config_key')
      .ifNotExists()
      .on('points_config')
      .column('key')
      .execute()

    // Point distributions indexes
    await db.schema
      .createIndex('idx_point_distributions_account_id')
      .ifNotExists()
      .on('point_distributions')
      .column('account_id')
      .execute()

    await db.schema
      .createIndex('idx_point_distributions_referrer_id')
      .ifNotExists()
      .on('point_distributions')
      .column('referrer_id')
      .execute()

    await db.schema
      .createIndex('idx_point_distributions_calculation_timestamp')
      .ifNotExists()
      .on('point_distributions')
      .column('calculation_timestamp')
      .execute()

    await db.schema
      .createIndex('idx_point_distributions_period')
      .ifNotExists()
      .on('point_distributions')
      .columns(['period_start', 'period_end'])
      .execute()

    // User activity status indexes
    await db.schema
      .createIndex('idx_user_activity_status_is_active')
      .ifNotExists()
      .on('user_activity_status')
      .column('is_active')
      .execute()

    await db.schema
      .createIndex('idx_user_activity_status_total_deposits')
      .ifNotExists()
      .on('user_activity_status')
      .column('total_deposits_usd')
      .execute()

    // Custom referral codes indexes
    await db.schema
      .createIndex('idx_custom_referral_codes_custom_code')
      .ifNotExists()
      .on('custom_referral_codes')
      .column('custom_code')
      .execute()

    await db.schema
      .createIndex('idx_custom_referral_codes_referrer_id')
      .ifNotExists()
      .on('custom_referral_codes')
      .column('actual_referrer_id')
      .execute()

    await db.schema
      .createIndex('idx_custom_referral_codes_is_active')
      .ifNotExists()
      .on('custom_referral_codes')
      .column('is_active')
      .execute()
  }

  private async migration001Down(db: Kysely<any>): Promise<void> {
    // Drop tables in reverse order
    await db.schema.dropTable('user_activity_status').ifExists().execute()
    await db.schema.dropTable('point_distributions').ifExists().execute()
    await db.schema.dropTable('custom_referral_codes').ifExists().execute()
    await db.schema.dropTable('points_config').ifExists().execute()
    await db.schema.dropTable('position_snapshots').ifExists().execute()
    await db.schema.dropTable('referral_points').ifExists().execute()
    await db.schema.dropTable('users').ifExists().execute()
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
        'custom_referral_codes',
        'referral_relationships',
        'users',
        'referral_points',
        'points_config',
        'migrations',
      ]

      for (const table of tablesToDrop) {
        await client.query(`DROP TABLE IF EXISTS ${table} CASCADE`)
        console.log(`Dropped table: ${table}`)
      }

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
