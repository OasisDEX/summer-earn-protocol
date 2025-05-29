# Referral Aggregator

This package aggregates referral data across multiple chains and calculates referral points based on user activity.

## Features

- **Hourly Processing**: Automatically processes referred accounts every hour with timestamp bounds
- **Cross-Chain Aggregation**: Aggregates referral data from multiple chains (Ethereum, Sonic, Arbitrum, Base)
- **Position Validation**: Validates that positions were created after referral timestamps
- **Pagination Support**: Handles large datasets with cursor-based pagination
- **Points Calculation**: Calculates referral points based on referred users' deposits
- **Historical Tracking**: Stores position snapshots for historical analysis
- **Database Migrations**: Automatic database schema management

## Architecture

### Hourly Processing Flow

1. **Account Discovery**: Every hour, fetch all referred accounts with timestamp bounds
   - First run: Only upper bound timestamp (all historical data)
   - Subsequent runs: Both lower and upper bounds (last hour's data)

2. **Validation**: Check if accounts have positions created before referral timestamp
   - Query positions with `createdTimestamp < referralTimestamp` 
   - Accounts with such positions are considered invalid

3. **Data Aggregation**: For valid accounts, fetch all positions using nested queries
   - Use `accounts { positions {} }` structure for efficient pagination
   - Paginate accounts (50 per batch) with guaranteed position retrieval

4. **Storage**: Store validated data in PostgreSQL database

### Database Schema

The package uses PostgreSQL to store referral data with the following schema:

#### Tables

1. `referral_points`
   - Stores calculated points for each account
   - Tracks total deposits and active referred users
   - Maintains last update timestamp

2. `referral_relationships`
   - Records referral relationships between users
   - Stores chain-specific referral timestamps
   - Ensures unique relationships per chain

3. `position_snapshots`
   - Stores historical position data
   - Tracks deposit amounts and timestamps
   - Links positions to referral relationships

4. `migrations`
   - Tracks applied database migrations
   - Ensures migrations are only run once

## GraphQL Queries

### Key Queries

1. **REFERRED_ACCOUNTS_QUERY**: Fetches accounts with referral timestamps in range
2. **ACCOUNTS_WITH_POSITIONS_QUERY**: Fetches accounts with nested positions (paginated)
3. **VALIDATE_POSITIONS_QUERY**: Checks for positions created before referral

### Pagination

All queries support cursor-based pagination:
```graphql
accounts(orderBy: id, first: $first, where: { id_gt: $lastId }) {
  # account fields
}
```

## Points Calculation

Referral points are calculated using the following formula:

```
points = total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1))
```

Where:
- `total_deposits`: Sum of all valid deposits from referred users
- `active_referred_users`: Number of referred users with active positions
- A position is considered valid if it was created after the referral timestamp

## Setup

### 1. Database Setup

Start PostgreSQL using Docker:

```bash
docker-compose up -d
```

This will start a PostgreSQL instance with:
- Database: `referral_points`
- User: `postgres`
- Password: `postgres`
- Port: `5432`

### 2. Environment Variables

Copy the example environment file and configure as needed:

```bash
cp env.example .env
```

Edit `.env` with your database configuration:
```bash
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=referral_points
DB_USER=postgres
DB_PASSWORD=postgres
```

### 3. Install Dependencies

```bash
pnpm install
```

### 4. Run Database Migrations

Initialize the database schema:

```bash
pnpm migrate
```

This will create all necessary tables and indexes.

### 5. Build the Package

```bash
pnpm build
```

## Usage

### Running Database Migrations

To manually run migrations:

```bash
pnpm migrate
```

Migrations are also automatically run when starting the hourly processor.

### Running Hourly Processor

To start the hourly processor (runs continuously):

```bash
pnpm hourly-processor
```

This will:
1. Run database migrations automatically
2. Run immediately on startup
3. Schedule to run every hour thereafter
4. Handle first run vs subsequent run logic automatically
5. Process all chains and store data in database

### Running Points Calculation

To calculate points for all accounts:

```bash
pnpm calculate-points
```

This will:
1. Take snapshots of all positions across chains
2. Calculate points for each account
3. Update the database with new point values

### API Usage

```typescript
import { 
  DatabaseService, 
  ReferralClient, 
  ReferralPointsService,
  HourlyProcessor 
} from '@summer-earn/referral-aggregator'

// Initialize services
const db = new DatabaseService()
const client = new ReferralClient()
const pointsService = new ReferralPointsService(db, client)
const processor = new HourlyProcessor(client, db)

// Run migrations
await db.migrate()

// Run hourly processing
await processor.processHourly()

// Calculate points for a specific account
await pointsService.calculatePoints('0x...')

// Get points for an account
const points = await db.getReferralPoints('0x...')

// Get referred users for an account
const referredUsers = await db.getReferredUsers('0x...')

// Process referred accounts with timestamp bounds
const { validAccounts, allReferredAccounts } = await client.processReferredAccountsHourly(
  BigInt(startTimestamp),
  BigInt(endTimestamp),
  false // isFirstRun
)
```

## Development

### Running Tests

```bash
pnpm test
```

### Watching Tests

```bash
pnpm test:watch
```

### Code Generation

```bash
pnpm codegen
```

### Database Management

#### Reset Database
To reset the database and re-run all migrations:

```bash
docker-compose down -v  # Remove volumes
docker-compose up -d    # Start fresh
pnpm migrate           # Run migrations
```

#### Add New Migration
1. Create a new SQL file in `src/migrations/` with format `XXX_description.sql`
2. Add your SQL statements
3. Run `pnpm migrate` to apply

## Monitoring

The hourly processor includes comprehensive logging:
- Processing start/completion times
- Account counts (total vs valid)
- Error handling and recovery
- Graceful shutdown on SIGINT/SIGTERM
- Migration status and progress

## Performance Considerations

- **Pagination**: Uses cursor-based pagination to handle large datasets
- **Batch Processing**: Processes accounts in batches of 50
- **Validation Optimization**: Early validation prevents unnecessary position fetching
- **Database Indexing**: Proper indexes on timestamp and ID fields for fast queries
- **Migration Safety**: Transactional migrations with rollback on failure

## License

MIT 