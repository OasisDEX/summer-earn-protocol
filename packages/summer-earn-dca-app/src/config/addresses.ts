import { type Address, getAddress } from 'viem'
import { base } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

// Canonical Permit2 address — deterministically deployed to every EVM chain.
// (See packages/deployment/scripts/common/constants.ts:7)
export const PERMIT2_ADDRESS: Address = getAddress('0x000000000022D473030F116dDEE9F6B43aC78BA3')

// DCAStrategyManager deployment per chain.
// (See packages/deployment/config/index.json — base.dca.dcaStrategyManager)
export const DCA_STRATEGY_MANAGER_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0x9407a57C1Ebe92cB7fc6CB68705e34371A33735A'),
}

// HarborCommand (active FleetCommander registry).
// Same address on base + mainnet (per packages/deployment/config/index.json).
export const HARBOR_COMMAND_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0x09eb323dBFECB43fd746c607A9321dACdfB0140F'),
}

// EnsoRouter — informational only (used by the keeper, not the FE).
export const ENSO_ROUTER_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0xf75584ef6673ad213a685a1b58cc0330b8ea22cf'),
}

// Known underlying token addresses on Base. Used to label fleet dropdowns
// and as the keys of FEED_BY_ASSET_ADDRESS below. Lowercased lookups happen
// at the call site — keep the checksummed forms here.
export const KNOWN_TOKEN_ADDRESSES: Record<ChainId, { weth: Address; usdc: Address }> = {
  [base.id]: {
    weth: getAddress('0x4200000000000000000000000000000000000006'),
    usdc: getAddress('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
  },
}

// Chainlink feed addresses on Base, keyed by the underlying ERC20 asset
// address (lowercased). When the user picks a source/target fleet, we read
// `fleet.asset()` and look up the feed here.
//
// Base-native feeds:
//   ETH/USD  : 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
//   USDC/USD : 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B
export const FEED_BY_ASSET_ADDRESS: Record<ChainId, Record<string, Address>> = {
  [base.id]: {
    [KNOWN_TOKEN_ADDRESSES[base.id].weth.toLowerCase()]: getAddress(
      '0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].usdc.toLowerCase()]: getAddress(
      '0x7e860098F58bBFC8648a4311b374B1D669a2bc6B',
    ),
  },
}

export function lookupFeedForAsset(chainId: ChainId, asset: Address | undefined): Address | undefined {
  if (!asset) return undefined
  return FEED_BY_ASSET_ADDRESS[chainId]?.[asset.toLowerCase()]
}
