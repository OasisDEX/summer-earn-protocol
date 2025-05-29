import { DatabaseService } from '../db'

async function main() {
  const db = new DatabaseService()

  try {
    console.log('Running database migrations...')
    await db.migrate()
    console.log('Database migrations completed successfully')
  } catch (error) {
    console.error('Error running migrations:', error)
    process.exit(1)
  } finally {
    await db.close()
  }
}

main()
