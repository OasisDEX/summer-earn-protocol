# Referral Aggregator

A comprehensive referral tracking and points calculation system that processes data from multiple blockchain networks and rewards referrers based on their referred users' activity.

## Features

### Enhanced Points System with Hourly Snapshots

The system now uses **hourly snapshots** from the subgraph for more accurate balance calculations:

- **Snapshot-based Processing**: Instead of using current position balances, the system fetches actual hourly snapshots for specific time periods
- **Historical Accuracy**: Backfill operations use snapshots from the exact time periods being processed
- **Consistent Data**: Both regular processing and backfill use the same data source for consistency
- **Time-specific Queries**: Process data for exact hourly windows (e.g., 2PM-3PM) using snapshot timestamps

### Points Calculation Formula

```
points = total_deposits_usd * (base_rate + log_multiplier * ln(active_users + 1))
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

### Enhanced Tables

- **`point_distributions`**: Individual point awards with timestamps
- **`user_activity_status`**: Active user tracking with deposit totals
- **`points_config`**: Runtime configuration management
- **`position_snapshots`**: Balance snapshots with timestamps

### Key Indexes

```sql
-- Performance indexes for snapshot processing
CREATE INDEX idx_position_snapshots_timestamp ON position_snapshots(snapshot_timestamp);
CREATE INDEX idx_position_snapshots_account_time ON position_snapshots(account_id, snapshot_timestamp);
CREATE INDEX idx_point_distributions_period ON point_distributions(period_start, period_end);
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