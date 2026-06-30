import { type Address, getAddress } from 'viem'
import { base, mainnet } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

// Canonical Permit2 address — deterministically deployed to every EVM chain.
// (See packages/deployment/scripts/common/constants.ts:7)
export const PERMIT2_ADDRESS: Address = getAddress('0x000000000022D473030F116dDEE9F6B43aC78BA3')

// DCAStrategyManager deployment per chain.
// NOTE: BOTH base + mainnet entries below are interim v4 addresses — they will
// be swapped to the audited v5 addresses post-deploy (bd aphelion-app-4z5).
export const DCA_STRATEGY_MANAGER_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0x82334fd233430C086ED7B9ED4723a7728d1eF292'),
  [mainnet.id]: getAddress('0x8044e2df8bF45f32E6021Bd342b4C734ffA64E0B'),
}

// HarborCommand (active FleetCommander registry).
// Same address on base + mainnet (per packages/deployment/config/index.json).
export const HARBOR_COMMAND_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0x09eb323dBFECB43fd746c607A9321dACdfB0140F'),
  [mainnet.id]: getAddress('0x09eb323dBFECB43fd746c607A9321dACdfB0140F'),
}

// EnsoRouter — informational only (used by the keeper, not the FE).
export const ENSO_ROUTER_ADDRESSES: Record<ChainId, Address> = {
  [base.id]: getAddress('0xf75584ef6673ad213a685a1b58cc0330b8ea22cf'),
  [mainnet.id]: getAddress('0xf75584ef6673ad213a685a1b58cc0330b8ea22cf'),
}

// Known underlying token addresses on Base. Used to label fleet dropdowns,
// drive the price-fetcher lookup, and as the keys of FEED_BY_ASSET_ADDRESS
// below. Lowercased lookups happen at the call site — keep the checksummed
// forms here.
export const KNOWN_TOKEN_ADDRESSES: Record<
  ChainId,
  {
    weth: Address
    usdc: Address
    wbtc: Address
    dai: Address
    arb: Address
    link: Address
  }
> = {
  [base.id]: {
    weth: getAddress('0x4200000000000000000000000000000000000006'),
    usdc: getAddress('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
    wbtc: getAddress('0x0555E30da8f98308EdB960aa94C0Db47230d2B9c'),
    dai: getAddress('0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb'),
    // The "Arbitrum" ARB token isn't natively on Base — using the wrapped
    // bridged variant address commonly used in token lists. Update when the
    // protocol team finalises the canonical Base wrapper.
    arb: getAddress('0xCF8e54a5af20C99e8DcF45d9D6b41AA6B7B3A2F2'),
    link: getAddress('0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196'),
  },
  [mainnet.id]: {
    weth: getAddress('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'),
    usdc: getAddress('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'),
    wbtc: getAddress('0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'),
    dai: getAddress('0x6B175474E89094C44Da98b954EedeAC495271d0F'),
    arb: getAddress('0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1'),
    link: getAddress('0x514910771AF9Ca656af840dff83E8264EcF986CA'),
  },
}

// Chainlink feed addresses on Base, keyed by the underlying ERC20 asset
// address (lowercased). When the user picks a source/target fleet, we read
// `fleet.asset()` and look up the feed here.
//
// Base-native feeds (data.chain.link/base):
//   ETH/USD   : 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70 (1200s heartbeat)
//   USDC/USD  : 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B (86400s)
//   BTC/USD   : 0x64c911996D3c6aC71f9b455B1E8E7266BcbDB7Ef (1200s)
//   DAI/USD   : 0x591e79239a7d679378eC8c847e5038150364C78F (86400s)
//   ARB/USD   : 0x3a236F3CcEaB8FbbC5C5Cd2B5Aa53FBC4F9c5fA0 (86400s)
//   LINK/USD  : 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65 (1200s)
export const FEED_BY_ASSET_ADDRESS: Record<ChainId, Record<string, Address>> = {
  [base.id]: {
    [KNOWN_TOKEN_ADDRESSES[base.id].weth.toLowerCase()]: getAddress(
      '0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].usdc.toLowerCase()]: getAddress(
      '0x7e860098F58bBFC8648a4311b374B1D669a2bc6B',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].wbtc.toLowerCase()]: getAddress(
      '0x64c911996D3c6aC71f9b455B1E8E7266BcbDB7Ef',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].dai.toLowerCase()]: getAddress(
      '0x591e79239a7d679378eC8c847e5038150364C78F',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].arb.toLowerCase()]: getAddress(
      '0x3a236F3CcEaB8FbbC5C5Cd2B5Aa53FBC4F9c5fA0',
    ),
    [KNOWN_TOKEN_ADDRESSES[base.id].link.toLowerCase()]: getAddress(
      '0x17CAb8FE31E32f08326e5E27412894e49B0f9D65',
    ),
  },
  // Mainnet-native Chainlink feeds (data.chain.link/ethereum-mainnet):
  //   ETH/USD   : 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
  //   USDC/USD  : 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
  //   BTC/USD   : 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
  //   DAI/USD   : 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9
  //   ARB/USD   : 0x31697852a68433DbCc2Ff612c516d69E3D9bd08F
  //   LINK/USD  : 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c
  [mainnet.id]: {
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].weth.toLowerCase()]: getAddress(
      '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    ),
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].usdc.toLowerCase()]: getAddress(
      '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6',
    ),
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].wbtc.toLowerCase()]: getAddress(
      '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c',
    ),
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].dai.toLowerCase()]: getAddress(
      '0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9',
    ),
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].arb.toLowerCase()]: getAddress(
      '0x31697852a68433DbCc2Ff612c516d69E3D9bd08F',
    ),
    [KNOWN_TOKEN_ADDRESSES[mainnet.id].link.toLowerCase()]: getAddress(
      '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c',
    ),
  },
}

export function lookupFeedForAsset(
  chainId: ChainId,
  asset: Address | undefined,
): Address | undefined {
  if (!asset) return undefined
  return FEED_BY_ASSET_ADDRESS[chainId]?.[asset.toLowerCase()]
}
