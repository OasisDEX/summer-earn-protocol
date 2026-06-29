import { encodeAbiParameters, type Hex, keccak256 } from 'viem'

import type { StrategyConfigTuple } from '@/types/strategy'

// Mirrors `keccak256(abi.encode(config))` from DCAStrategyManager.sol —
// used to verify against `strategyCommitments(id)` from RPC and to drive the
// `activeCommitments(commitment)` pre-flight duplicate check in the create
// wizard. `strategyId` is NOT part of the hash (it lives outside the struct).
const STRATEGY_CONFIG_TUPLE_TYPE = {
  type: 'tuple',
  components: [
    { name: 'owner', type: 'address' },
    { name: 'sourceVault', type: 'address' },
    { name: 'targetVault', type: 'address' },
    { name: 'inAsset', type: 'address' },
    { name: 'outAsset', type: 'address' },
    {
      name: 'inAssetFeed',
      type: 'tuple',
      components: [
        { name: 'feed', type: 'address' },
        { name: 'maxStaleness', type: 'uint256' },
      ],
    },
    {
      name: 'outAssetFeed',
      type: 'tuple',
      components: [
        { name: 'feed', type: 'address' },
        { name: 'maxStaleness', type: 'uint256' },
      ],
    },
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
