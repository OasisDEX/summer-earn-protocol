# Referral Aggregator

This package aggregates referral data across multiple chains and calculates referral points based on user activity.

## Features

- Aggregates referral data from multiple chains (Ethereum, Polygon, Arbitrum, Base)
- Calculates referral points based on referred users' deposits
- Stores position snapshots for historical tracking
- Handles cross-chain referral relationships

## Database Schema

The package uses PostgreSQL to store referral data with the following schema:

### Tables

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

1. Install dependencies:
   ```bash
   pnpm install
   ```

2. Set up environment variables:
   ```bash
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=referral_points
   DB_USER=postgres
   DB_PASSWORD=postgres
   ```

3. Build the package:
   ```bash
   pnpm build
   ```

## Usage

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
import { DatabaseService, ReferralClient, ReferralPointsService } from '@summer-earn/referral-aggregator'

const db = new DatabaseService()
const client = new ReferralClient()
const service = new ReferralPointsService(db, client)

// Calculate points for a specific account
await service.calculatePoints('0x...')

// Get points for an account
const points = await db.getReferralPoints('0x...')

// Get referred users for an account
const referredUsers = await db.getReferredUsers('0x...')
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

## License

MIT 