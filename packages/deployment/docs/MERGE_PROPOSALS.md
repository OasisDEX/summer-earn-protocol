# Merge Proposals Script

## Overview

The merge proposals script allows you to combine multiple governance proposals into a single unified proposal. This is particularly useful when you need to deploy arks to multiple fleets in a coordinated manner.

## Use Cases

1. **Multi-Fleet Ark Additions**: Deploy arks to multiple fleets (same or different chains) with a single governance vote
2. **Coordinated Cross-Chain Actions**: Combine multiple cross-chain proposals targeting different chains
3. **Batch Operations**: Group related governance actions that should be executed together

## How It Works

The script:
1. Loads multiple proposal JSON files from the `proposals/` directory
2. Validates that all proposals use the same governor (required for merging)
3. Merges the proposal data:
   - **Hub Actions**: Concatenates `targets`, `values`, and `calldatas` arrays
   - **Cross-Chain Actions**: Groups cross-chain executions by target chain ID, merging actions for the same chain
4. Generates a merged proposal with combined title and description
5. Saves the merged proposal to a new JSON file

## Usage

### Run the Script

```bash
cd packages/deployment
pnpm gov:merge-proposals
```

### Interactive Flow

1. **Select Proposals**: Choose 2+ proposal files to merge (multiselect with space bar)
2. **Validation**: Script validates all proposals use the same governor
3. **Custom Title/Description**: Optionally provide custom text, or use auto-generated summary
4. **Review**: See summary of merged proposal including:
   - Total hub actions
   - Cross-chain execution details (grouped by chain)
5. **Confirm & Save**: Save the merged proposal
6. **Cleanup**: Optionally delete original proposal files

## Data Structure

### Input: Individual Proposals

Each proposal JSON has this structure:

```json
{
  "title": "SIP1.X: Add Ark to Fleet A",
  "description": "# Proposal...",
  "governorId": "eip155:1:0x...",
  "targets": ["0x..."],
  "values": ["0"],
  "calldatas": ["0x..."],
  "discourseURL": "https://...",
  "timestamp": 1234567890,
  "crossChainExecution": {
    "targetChain": {
      "name": "arbitrum",
      "chainId": 42161,
      "targets": ["0x..."],
      "values": ["0"],
      "datas": ["0x..."]
    }
  }
}
```

### Output: Merged Proposal

The merged proposal combines all actions:

```json
{
  "title": "Merged Proposal: Add Arks to Multiple Fleets",
  "description": "# Combined proposal...",
  "governorId": "eip155:1:0x...",
  "targets": ["0x...", "0x...", ...],       // All hub actions
  "values": ["0", "0", ...],
  "calldatas": ["0x...", "0x...", ...],
  "discourseURL": "https://..., https://...",
  "timestamp": 1234567890,
  "crossChainExecution": [                   // Grouped by chain
    {
      "name": "arbitrum",
      "chainId": 42161,
      "targets": ["0x...", "0x..."],         // Merged actions for Arbitrum
      "values": ["0", "0"],
      "datas": ["0x...", "0x..."]
    },
    {
      "name": "base",
      "chainId": 8453,
      "targets": ["0x..."],                  // Actions for Base
      "values": ["0"],
      "datas": ["0x..."]
    }
  ]
}
```

## Cross-Chain Execution Merging

The script intelligently handles cross-chain proposals:

- **Same Target Chain**: If multiple proposals target the same chain (e.g., both add arks to Arbitrum), the script merges them into a single cross-chain execution with combined actions
- **Different Target Chains**: If proposals target different chains, each chain gets its own entry in the `crossChainExecution` array
- **Mixed Hub/Cross-Chain**: Hub actions are always kept separate from cross-chain actions

### Example

**Input**: Two proposals
- Proposal A: Add ark to Fleet 1 on Arbitrum (3 actions)
- Proposal B: Add ark to Fleet 2 on Arbitrum (3 actions)

**Output**: Merged proposal with:
- Hub actions: 2 (one `sendProposalToTargetChain` call per original proposal)
- Cross-chain execution for Arbitrum: 6 actions (3 + 3 merged)

## Validation

The script performs these validations:

✅ **Same Governor**: All proposals must use the same governor address
✅ **Minimum Count**: At least 2 proposals required
✅ **Valid Structure**: Each proposal must have valid `targets`, `values`, `calldatas` arrays

## Workflow Example

### Scenario: Add Arks to 3 Fleets on Different Chains

1. **Deploy Arks**: Run `deploy-fleet.ts` in "Add Ark" mode for each fleet
   - This creates 3 separate proposal JSON files

2. **Merge Proposals**: Run `pnpm gov:merge-proposals`
   - Select all 3 proposal files
   - Provide a unified title like "SIP2.42: Add MEV Protection Arks to USDC Fleets"
   - Confirm and save

3. **Submit to Tally**: Use the merged proposal JSON to submit a single governance proposal

4. **Result**: One vote approves all 3 ark additions across all chains

## Best Practices

1. **Thematic Grouping**: Merge proposals that are logically related (e.g., all related to the same feature launch)
2. **Clear Titles**: Use descriptive titles that explain the combined action
3. **Discourse Links**: If each original proposal has a Discourse thread, all URLs are preserved
4. **Review Carefully**: Always review the merged proposal summary before saving
5. **Keep Originals**: Consider keeping original proposal files until the merged proposal is successfully submitted

## Limitations

- Cannot merge proposals with different governors (different chains have different governors)
- For cross-chain proposals, must originate from the hub chain
- Description merging is concatenative (consider writing custom description for clarity)

## Troubleshooting

### Error: "Cannot merge proposals with different governor addresses"

**Cause**: The selected proposals were created for different governor contracts (e.g., mixing mainnet and testnet proposals)

**Solution**: Only merge proposals created for the same network/governor

### Error: "You must select at least 2 proposals to merge"

**Cause**: Less than 2 proposals were selected

**Solution**: Select 2 or more proposals using the space bar in the multiselect prompt

## Related Scripts

- `deploy-fleet.ts`: Creates individual proposals for fleet/ark operations
- `gov:submit-proposal`: Submits a proposal to the governance system
- `gov:execute-proposal`: Executes an approved proposal

## Technical Details

The merge logic handles these array operations:

```typescript
// Hub actions: Simple concatenation
mergedTargets = [...proposal1.targets, ...proposal2.targets, ...]
mergedValues = [...proposal1.values, ...proposal2.values, ...]
mergedCalldatas = [...proposal1.calldatas, ...proposal2.calldatas, ...]

// Cross-chain: Group by chainId, then concatenate
for each chain:
  chainTargets = [...proposal1.chain.targets, ...proposal2.chain.targets, ...]
  chainValues = [...proposal1.chain.values, ...proposal2.chain.values, ...]
  chainDatas = [...proposal1.chain.datas, ...proposal2.chain.datas, ...]
```

This ensures:
- All actions execute in the correct order
- Cross-chain messages have the complete set of actions per chain
- The proposal structure remains valid for the governance system


