import { CHAIN_CONFIG, SupportedChainId } from './constants'

export interface TreasuryWallet {
  key: string
  label: string
  // Per-chain address for this wallet. A chain that is omitted is not scanned.
  addresses: Partial<Record<SupportedChainId, string>>
  // Optional external link (e.g. the Arcadia foundry account page).
  externalUrl?: string
}

const SUPPORTED_CHAIN_IDS = Object.keys(CHAIN_CONFIG).map(Number) as SupportedChainId[]

// Use the same address on every supported chain. Chains where the wallet holds
// nothing simply contribute no holdings (zero balances are filtered out).
function onAllChains(address: string): Partial<Record<SupportedChainId, string>> {
  return Object.fromEntries(SUPPORTED_CHAIN_IDS.map((chainId) => [chainId, address])) as Partial<
    Record<SupportedChainId, string>
  >
}

// Named wallets shown as their own sections in the treasury, in addition to the
// main treasury (derived from CHAIN_CONFIG[chainId].timelock in the service).
export const TREASURY_WALLETS: TreasuryWallet[] = [
  {
    key: 'arcadia-control',
    label: 'Arcadia Control Multisig',
    addresses: onAllChains('0x89b39e0007577e5aE3d9f87CAaeaC4d2A3db5B34'),
  },
  {
    // AccountV4 spot account (Base) owned by the Arcadia Control Multisig. It
    // exposes no on-chain value/asset getter, so we value it from the tokens it
    // holds directly (currently SUMR). LP/CL positions, if ever held, would need
    // an off-chain source — see the linked foundry page for the full breakdown.
    key: 'arcadia-pol',
    label: 'Arcadia PoL',
    addresses: { 8453: '0x18A2D63cE434DD77e2b518458E636aA7ff4d7cc8' },
    externalUrl:
      'https://foundry.arcadia.finance/account/8453/0x18A2D63cE434DD77e2b518458E636aA7ff4d7cc8',
  },
  {
    key: 'aerodrome',
    label: 'Aerodrome Multisig',
    addresses: onAllChains('0x95e346c0c8405C0996bb3d5f51264c92345d68BC'),
  },
  {
    key: 'guardians',
    label: 'Guardians',
    addresses: onAllChains('0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4'),
  },
  {
    key: 'delegate-rewards',
    label: 'Delegate Rewards',
    addresses: onAllChains('0x9a218f744EE78E7a84e1C28acbcc2ce5cC72Bb0E'),
  },
]
