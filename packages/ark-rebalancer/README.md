# ark-rebalancer

A proof-of-concept Python bot that monitors all arks registered under a single `FleetCommander`
contract and automatically rebalances funds toward the highest-yielding ark. Every 10 seconds it
polls each ark's `rate()`; once the same ark has held the top rate for 12 consecutive polls (~2
minutes), it calls `fleetCommander.rebalance()` to move the full `totalAssets()` of every other ark
into the top ark.

## Key files

| File                | Description                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `ark_rebalancer.py` | Single-file entry point; contains the polling loop, rate comparison, rebalance logic, and inlined ABIs |
| `requirements.txt`  | Pinned Python dependencies (web3==5.31.1, requests==2.32.4, mypy==1.11.0, python-dotenv==1.2.2)        |
| `setup.py`          | Registers the `ark-rebalancer` console-script entry point                                              |
| `mypy.ini`          | mypy configuration (Python 3.9, warn_return_any, warn_unused_configs)                                  |

## Running

This package has no `package.json`; it is pure Python.

```bash
# Install dependencies
pip install -r packages/ark-rebalancer/requirements.txt

# Or install as a console script
pip install -e packages/ark-rebalancer

# Set required env vars (create a .env file or export them)
BASE_RPC_URL=<http-rpc>
DEPLOYER_PRIV_KEY=<hex-private-key>
FLEET_COMMANDER_ADDRESS=<0x...>

# Run
python packages/ark-rebalancer/ark_rebalancer.py
# or, after pip install -e:
ark-rebalancer
```

## Cross-package connections

**Consumes:** environment variables only (`BASE_RPC_URL`, `DEPLOYER_PRIV_KEY`,
`FLEET_COMMANDER_ADDRESS`). It does not import any other package in this monorepo.

**Consumed by:** nothing — no other package depends on this one.

**Agent gotchas:**

- The `FleetCommander` and `Ark` ABIs are hand-copied JSON string literals inside
  `ark_rebalancer.py` (lines 20-22). They are not generated from `core-contracts`. If the
  `FleetCommander` or `Ark` interfaces change, these literals must be updated manually.
- Only a two-function subset of `FleetCommander` (`arks`, `rebalance`) and two functions of `Ark`
  (`rate`, `totalAssets`) are inlined; other interface changes will not be noticed automatically.
- Gas is hardcoded at `2000000`; there is no dynamic estimation.
- Supports a single fleet on a single chain at a time (determined entirely by env vars).
