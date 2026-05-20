import { encodeAbiParameters, type Hex,keccak256 } from 'viem'

import type { StrategyConfigTuple } from '@/types/strategy'

// Mirrors `keccak256(abi.encode(config))` from DCAStrategyManager.sol.
// Used purely for parity assertions against `strategyCommitments(id)` from RPC —
// if our reconstruction is correct, the two hashes match.
const STRATEGY_CONFIG_TUPLE_TYPE = {
  type: 'tuple',
  components: [
    { name: 'strategyId', type: 'uint256' },
    { name: 'owner', type: 'address' },
    { name: 'sourceVault', type: 'address' },
    { name: 'targetVault', type: 'address' },
    { name: 'inAsset', type: 'address' },
    { name: 'outAsset', type: 'address' },
    { name: 'inAssetFeed', type: 'address' },
    { name: 'outAssetFeed', type: 'address' },
    { name: 'tradeAmount', type: 'uint256' },
    { name: 'interval', type: 'uint256' },
    { name: 'slippageBps', type: 'uint256' },
    { name: 'maxPrice', type: 'uint256' },
    { name: 'minPrice', type: 'uint256' },
    { name: 'endDate', type: 'uint256' },
    { name: 'maxTrades', type: 'uint256' },
  ],
} as const

export function computeCommitment(config: StrategyConfigTuple): Hex {
  const encoded = encodeAbiParameters([STRATEGY_CONFIG_TUPLE_TYPE], [config])
  return keccak256(encoded)
}
