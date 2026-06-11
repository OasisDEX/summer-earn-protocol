---
description: An index of the Summer.fi Earn Protocol subgraphs and how to query them.
---

# Subgraphs / Data

The Summer.fi Earn Protocol exposes its on-chain state through a set of The Graph subgraphs. Each subgraph indexes a distinct domain — vault activity, market rates, governance, and DCA strategies — and serves a standard GraphQL API that developers can query without running their own node.

## Subgraph index

| Subgraph | Domain | Networks |
|---|---|---|
| [Protocol](protocol-subgraph.md) | Vaults, Arks, deposits, withdrawals, rebalances, positions | Ethereum, Arbitrum, Base, Sonic, HyperEVM |
| [Rates](rates-subgraph.md) | Live and historical borrow/supply APYs per Ark product | Ethereum, Arbitrum, Base, Optimism, Sonic, HyperEVM |
| [Governance](governance-subgraph.md) | Proposals, votes, cross-chain execution, roles, delegates | HyperEVM |
| [DCA](dca-subgraph.md) | DCA strategies, trade executions, Chainlink price feeds | Base |

Additional subgraphs present in the monorepo (auctions, institutions, institutions-v2, shareseconds) are not documented here; they follow the same pattern but serve internal or specialised use cases.

## How to query

All subgraphs expose a standard GraphQL endpoint. The exact URL is deployment-specific and depends on the hosted-service or Goldsky slug used at deploy time.

> **TODO (human input required):** replace the placeholder URLs below with the production endpoints once deployments are finalised.

```
# Protocol subgraph (example — replace with real URL)
POST https://<subgraph-host>/subgraphs/name/summerfi/summer-earn-protocol-<network>

# Rates subgraph
POST https://<subgraph-host>/subgraphs/name/summerfi/summer-earn-rates-<network>

# Governance subgraph
POST https://<subgraph-host>/subgraphs/name/summerfi/summer-earn-protocol-gov-<network>

# DCA subgraph (Goldsky slug: summer-dca-base)
POST https://subgraph.staging.oasisapp.dev/summer-dca-base
```

All endpoints accept `application/json` POST requests with a `query` field.

### Example request

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"{ vaults(first: 5) { id name totalValueLockedUSD } }"}' \
  https://<protocol-subgraph-url>
```

### Pagination

The Graph returns at most 1 000 records per request by default. Use `first` and `skip` (or cursor-based `id_gt`) to paginate large result sets:

```graphql
{
  deposits(first: 100, skip: 200, orderBy: timestamp, orderDirection: desc) {
    id
    amount
    amountUSD
    timestamp
  }
}
```

## Schema versioning

| Subgraph | Schema version |
|---|---|
| Protocol | 1.3.1 (Messari Yield Aggregator schema) |
| Rates | custom |
| Governance | custom |
| DCA | custom |

## Source locations

All subgraph source lives inside the `summer-earn-protocol` monorepo:

- `packages/summer-earn-protocol-subgraph`
- `packages/summer-earn-rates-subgraph`
- `packages/summer-earn-protocol-gov-subgraph`
- `packages/summer-earn-dca-subgraph`

Additional subgraphs (auctions, institutions, shareseconds, …) follow the same directory layout under `packages/`.
