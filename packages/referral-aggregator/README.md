# Referral Aggregator

## 🚀 Recent Consolidation

The referral aggregator has been streamlined into a unified structure that focuses on essential operations. All processing logic is now consolidated into a single processor with a unified entry point that supports:

- **Processing** - Hourly referral points calculation
- **Backfilling** - Historical points calculation using the same logic
- **Statistics** - View current stats and top referrers

See [CONSOLIDATION.md](./CONSOLIDATION.md) for detailed information about the new structure.

### Quick Start

```bash
# Process latest period
npm run process

# Backfill from beginning
npm run backfill

# Show statistics
npm run stats

# Show help
npm run execute -- --help
```

A comprehensive referral tracking and points calculation system that processes data from multiple blockchain networks and rewards referrers based on their referred users' activity.

## Features

### Enhanced Points System with Hourly Snapshots

The system now uses **hourly snapshots** from the subgraph for more accurate balance calculations:

- **Snapshot-based Processing**: Instead of using current position balances, the system fetches actual hourly snapshots for specific time periods
- **Historical Accuracy**: Backfill operations use snapshots from the exact time periods being processed
- **Consistent Data**: Both regular processing and backfill use the same data source for consistency
- **Time-specific Queries**: Process data for exact hourly windows (e.g., 2PM-3PM) using snapshot timestamps

### Points Calculation Formula

```points = total_deposits_usd * (base_rate + log_multiplier * ln(active_users + 1))
```

**Default Configuration:**
- `base_rate`: 0.00005 (configurable)
- `log_multiplier`: 0.0005 (configurable)  
- `active_user_threshold`: $100 USD (configurable)
- `processing_interval`: 1 hour (configurable)

### Key Features

- **Multi-chain Support**: Ethereum, Sonic, Arbitrum, Base
- **Hourly Processing**: Automated points calculation every hour using snapshots
- **Active User Concept**: Users with ≥$100 USD deposits (configurable)
- **Historical Backfill**: Process historical data using time-specific snapshots
- **Point Distribution Tracking**: Individual point awards with timestamps
- **Configuration Management**: Runtime configuration updates
- **Type-safe Database**: Kysely integration for compile-time query validation

## GraphQL Snapshots Integration

The system uses the following GraphQL query structure to fetch hourly snapshots:

```graphql
{
  accounts {
    positions {
      hourlySnapshots(where: {timestamp_gt: $timestampGt, timestamp_lt: $timestampLt}) {
        inputTokenBalanceNormalizedInUSD
        stakedInputTokenBalanceNormalizedInUSD
        unstakedInputTokenBalanceNormalizedInUSD
        timestamp
      }
    }
  }
}
```

This ensures we get balance data for specific time windows, enabling:
- Accurate historical processing
- Consistent hourly calculations
- Time-specific point awards

## Usage

### Enhanced Processor with Snapshots

```bash
# Start with snapshots and backfill
npm run enhanced-processor-snapshots

# Start without backfill
npm run enhanced-processor-snapshots --no-backfill

# Show help
npm run enhanced-processor-snapshots --help
```

### Legacy Processor (Current Balance)

```bash
# Original processor using current position balances
npm run enhanced-processor

# Start without backfill
npm run enhanced-processor --no-backfill
```

### Backfill Operations

```bash
# Backfill from earliest referral
npm run backfill

# Backfill from specific date
npm run backfill 2024-01-01

# Show backfill help
npm run backfill --help
```

### Statistics and Monitoring

```bash
# Show system statistics
npm run stats

# Show specific account details
npm run stats 0x1234567890abcdef...

# Show configuration
npm run config --show
```

### Configuration Management

```bash
# Update processing interval to 2 hours
npm run config processing_interval_hours 2

# Update active user threshold to $200
npm run config active_user_threshold_usd 200

# Update points formula parameters
npm run config points_formula_base 0.0001
npm run config points_formula_log_multiplier 0.001

# Enable/disable backfill
npm run config enable_backfill true
```

## Snapshot vs Current Balance Comparison

| Feature | Snapshot-based | Current Balance |
|---------|---------------|-----------------|
| **Accuracy** | ✅ Historical accuracy | ⚠️ Current state only |
| **Backfill** | ✅ Time-specific data | ⚠️ Approximate |
| **Consistency** | ✅ Same data source | ⚠️ Different approaches |
| **Performance** | ⚠️ More queries | ✅ Simpler queries |
| **Use Case** | Production/Analysis | Development/Testing |

## Database Schema

The referral aggregator uses a simplified database schema with a clean one-to-many referral relationship structure:

### Core Tables

#### 🙋‍♂️ **Users Table**
The central table that manages all users and their referral relationships:

- **Primary Key**: `(id, chain)` - Each user exists once per chain
- **One-to-Many Relationship**: One referrer can have multiple referred users, but each user can only have one referrer per chain
- **Columns**:
  - `id` - User's wallet address
  - `chain` - Blockchain network (Ethereum, Sonic, Arbitrum, Base)
  - `referrer_id` - Address of the user who referred them (nullable)
  - `referral_timestamp` - When they were referred (nullable)
  - `created_at` - Record creation timestamp
  - `updated_at` - Auto-updated on modifications

#### 🏆 **Referral Points Table**
Tracks accumulated points for referrers:
- `account_id` - Referrer's address (primary key)
- `points` - Total points earned
- `total_deposits_usd` - Total USD deposits from referred users
- `active_referred_users` - Count of active referred users
- `last_calculation_timestamp` - When points were last calculated

#### 📊 **Position Snapshots Table**  
Stores user position data from subgraphs:
- `account_id` - User's address
- `chain` - Blockchain network
- `position_id` - Unique position identifier  
- `deposit_amount_usd` - USD value of deposits
- `created_timestamp` - When position was created
- `snapshot_timestamp` - When snapshot was taken

#### 📈 **Point Distributions Table**
Historical record of all point distributions:
- `account_id` - Referrer who received points
- `points_awarded` - Points given in this distribution
- `period_start` / `period_end` - Time period for calculation
- `active_referred_users` - Number of active users at time of calculation

#### 🎯 **User Activity Status Table**
Tracks user activity and eligibility:
- `account_id` - User's address
- `total_deposits_usd` - Total deposits across all positions
- `is_active` - Whether user meets activity threshold
- `last_deposit_timestamp` - Most recent deposit

#### 🏷️ **Custom Referral Codes Table**
Maps custom codes to actual referrer addresses:
- `custom_code` - Human-readable code (e.g., "boobo")
- `actual_referrer_id` - Real referrer address
- `referrer_address` - Display address for the referrer
- `is_active` - Whether code is currently valid

### Key Benefits of New Schema

1. **Simplified Relationships**: Direct one-to-many relationship in users table
2. **Data Integrity**: Each user can only be referred once per chain  
3. **Cross-Chain Support**: Users exist independently on each chain
4. **Custom Codes Ready**: Built-in support for branded referral codes
5. **Audit Trail**: Complete history of point distributions
6. **Performance**: Optimized indexes for fast queries

### Migration Strategy

The schema was completely reset and rebuilt with:
- ✅ Clean one-to-many referral structure
- ✅ Automatic `updated_at` triggers
- ✅ Comprehensive indexing
- ✅ All existing functionality preserved
- ✅ Custom referral codes infrastructure

### Example Queries

```sql
-- Get all users referred by a specific referrer
SELECT * FROM users WHERE referrer_id = '0x123...';

-- Count active referred users for a referrer  
SELECT COUNT(*) FROM users u
JOIN user_activity_status uas ON u.id = uas.account_id
WHERE u.referrer_id = '0x123...' AND uas.is_active = true;

-- Get referral hierarchy for a chain
SELECT u.id, u.referrer_id, u.referral_timestamp 
FROM users u 
WHERE u.chain = 'Ethereum' 
ORDER BY u.referral_timestamp;
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Subgraph      │    │   GraphQL        │    │   Enhanced      │
│   (Hourly       │◄───┤   Client         │◄───┤   Processor     │
│   Snapshots)    │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐             │
│   Configuration │◄───┤   Database       │◄────────────┘
│   Service       │    │   (Kysely +      │
│                 │    │   Raw SQL)       │
└─────────────────┘    └──────────────────┘
                                │
                       ┌──────────────────┐
                       │   Points         │
                       │   Calculation    │
                       │   Service        │
                       └──────────────────┘
```

## Environment Variables

```bash
# Database Configuration
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=referral_points
DB_USER=postgres
DB_PASSWORD=postgres

# Optional: Custom subgraph URLs
ETHEREUM_SUBGRAPH_URL=https://subgraph.staging.oasisapp.dev/summer-protocol
SONIC_SUBGRAPH_URL=https://subgraph.staging.oasisapp.dev/summer-protocol-sonic
ARBITRUM_SUBGRAPH_URL=https://subgraph.staging.oasisapp.dev/summer-protocol-arbitrum
BASE_SUBGRAPH_URL=https://subgraph.staging.oasisapp.dev/summer-protocol-base
```

## Migration Guide

### From Current Balance to Snapshots

1. **Test Environment**: Start with `enhanced-processor-snapshots` in test environment
2. **Compare Results**: Run both processors and compare point calculations
3. **Gradual Migration**: Switch to snapshots for new deployments
4. **Data Validation**: Verify historical backfill accuracy

### Configuration Updates

```bash
# Recommended production settings
npm run config processing_interval_hours 1
npm run config active_user_threshold_usd 100
npm run config points_formula_base 0.00005
npm run config points_formula_log_multiplier 0.0005
npm run config enable_backfill true
```

## Troubleshooting

### Common Issues

1. **No Snapshots Found**: Ensure timestamp ranges are correct and snapshots exist
2. **Performance Issues**: Check database indexes and query optimization
3. **Configuration Errors**: Verify database connection and config table setup
4. **Type Errors**: Ensure Kysely types are up to date

### Debug Commands

```bash
# Check snapshot data
npm run stats

# Verify configuration
npm run config --show

# Test specific time range
npm run backfill 2024-01-01 --verbose
```

### Monitoring

Monitor these key metrics:
- Point distributions per hour
- Active user count trends
- Processing time per cycle
- Database query performance
- Snapshot data availability

## Development

### Building

```bash
npm run build
```

### Testing

```bash
npm test
npm run test:watch
```

### Type Checking

```bash
npx tsc --noEmit
```

## Contributing

1. Use TypeScript for type safety
2. Add tests for new features
3. Update documentation
4. Follow existing code patterns
5. Test with both processors (snapshot and current)

---

**Note**: The snapshot-based approach is recommended for production use due to its improved accuracy and consistency. The current balance approach remains available for development and testing purposes. 