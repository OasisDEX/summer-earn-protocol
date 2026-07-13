import path from 'node:path'

import { Address, formatUnits, maxUint256, parseAbi } from 'viem'

import { SafeAbiFunctionFragment } from '../../helpers/safe-tx-builder'

/**
 * Shared pieces of the config-driven fleet-cleanup tooling:
 *  - `gov:cleanup-fleets:init`  (init.ts)          — generates one editable JSON per fleet
 *  - `gov:cleanup-fleets`      (build-batches.ts)  — turns those JSONs into governance proposals
 *                                                    (default) or Safe Transaction Builder batches
 *                                                    (MODE=safe), one output per fleet
 *
 * Config files live in config/fleet-cleanup/<network>/<FleetName>.json and are the operator's
 * worksheet: every ark defaults to `action: "leave"`; flipping an action and re-running the
 * build script emits one output per fleet.
 */

export type CleanupAction =
  | 'leave'
  | 'socializeLosses'
  | 'socializeLossesAndRemove'
  | 'removeArk'
  | 'requestWithdrawal'

export const CLEANUP_ACTIONS: readonly CleanupAction[] = [
  'leave',
  'socializeLosses',
  'socializeLossesAndRemove',
  'removeArk',
  'requestWithdrawal',
]

export interface CleanupArkEntry {
  name: string
  address: Address
  isBufferArk: boolean
  totalAssets: string
  totalAssetsFormatted: string
  depositCap: string
  depositCapFormatted: string
  protocol: string | null
  pool: Address | null
  action: CleanupAction
}

export interface FleetCleanupConfig {
  network: string
  chainId: number
  configType: 'prod' | 'test'
  generatedAt: string
  fleetName: string
  fleetAddress: Address
  bufferArk: Address
  asset: Address
  assetSymbol: string
  assetDecimals: number
  fleetTotalAssets: string
  fleetTotalAssetsFormatted: string
  paused: boolean
  unpauseNotBefore: string | null
  /** When true, the generated batch ends with pause() — note this restarts the minimum pause window. */
  repauseAfter: boolean
  arks: CleanupArkEntry[]
}

export const arkAbi = parseAbi([
  'function name() view returns (string)',
  'function commander() view returns (address)',
  'function totalAssets() view returns (uint256)',
  'function depositCap() view returns (uint256)',
  'function details() view returns (string)',
  'function asset() view returns (address)',
])

export const fleetAbi = parseAbi([
  'function name() view returns (string)',
  'function getActiveArks() view returns (address[])',
  'function bufferArk() view returns (address)',
  'function paused() view returns (bool)',
  'function pauseStartTime() view returns (uint256)',
  'function minimumPauseTime() view returns (uint256)',
  'function asset() view returns (address)',
  'function totalAssets() view returns (uint256)',
])

export const harborCommandAbi = parseAbi([
  'function getActiveFleetCommanders() view returns (address[])',
])

export const raftViewAbi = parseAbi([
  'function sweepableTokens(address ark, address token) view returns (bool)',
  'function nonSweepableTokens(address ark, address token) view returns (bool)',
])

export const pamViewAbi = parseAbi([
  'function GOVERNOR_ROLE() view returns (bytes32)',
  'function generateRole(uint8 roleName, address roleTargetContract) pure returns (bytes32)',
  'function hasRole(bytes32 role, address account) view returns (bool)',
])

export const erc20Abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
])

// Async-withdrawal arks (OriginUSDArk, SyrupArk/V2, …) implement IArkWithWithdrawalRequest.
// Used to validate a `requestWithdrawal` action target and detect an already-pending request.
export const arkWithdrawalViewAbi = parseAbi([
  'function withdrawalRequestId() view returns (uint256)',
  'function assetsInWithdrawalQueue() view returns (uint256)',
  'function isWithdrawalClaimRequired() view returns (bool)',
])

export const CURATOR_ROLE_ENUM = 0 // ContractSpecificRoles.CURATOR_ROLE
export const KEEPER_ROLE_ENUM = 1 // ContractSpecificRoles.KEEPER_ROLE

// requestWithdrawal(type(uint256).max) requests the ark's full position.
export const WITHDRAWAL_REQUEST_MAX = maxUint256

// Write ABIs as JSON fragments so the Safe Transaction Builder `contractMethod` metadata can be
// derived from the same source used for calldata encoding.
export const writeAbis = {
  grantCuratorRole: {
    name: 'grantCuratorRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  revokeCuratorRole: {
    name: 'revokeCuratorRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  // grantKeeperRole/revokeKeeperRole scope KEEPER_ROLE to the address passed as the first arg —
  // pass an ARK address for an ark-scoped keeper (required for Ark.requestWithdrawal), not a fleet.
  grantKeeperRole: {
    name: 'grantKeeperRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  revokeKeeperRole: {
    name: 'revokeKeeperRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  requestWithdrawal: {
    name: 'requestWithdrawal',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  setSweepableToken: {
    name: 'setSweepableToken',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'isSweepable', type: 'bool' },
    ],
    outputs: [],
  },
  setNonSweepableToken: {
    name: 'setNonSweepableToken',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'isNonSweepable', type: 'bool' },
    ],
    outputs: [],
  },
  socializeLosses: {
    name: 'socializeLosses',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'tokens', type: 'address[]' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [],
  },
  setArkDepositCap: {
    name: 'setArkDepositCap',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'newDepositCap', type: 'uint256' },
    ],
    outputs: [],
  },
  removeArk: {
    name: 'removeArk',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'ark', type: 'address' }],
    outputs: [],
  },
  unpause: {
    name: 'unpause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  pause: {
    name: 'pause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  // Percentage is an 18-decimal-fixed-point uint256 (@summerfi/percentage-solidity).
  setTipRate: {
    name: 'setTipRate',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'newTipRate', type: 'uint256' }],
    outputs: [],
  },
} as const satisfies Record<string, SafeAbiFunctionFragment>

export function cleanupConfigDir(network: string): string {
  return path.join(__dirname, '..', '..', '..', 'config', 'fleet-cleanup', network)
}

export function proposalsDir(): string {
  return path.join(__dirname, '..', '..', '..', 'proposals')
}

export function sanitizeFleetName(fleetName: string): string {
  return fleetName.replace(/[^a-zA-Z0-9_-]/g, '_')
}

export function formatAssets(raw: bigint, decimals: number, symbol: string): string {
  return `${formatUnits(raw, decimals)} ${symbol}`
}

export function formatCap(raw: bigint, decimals: number, symbol: string): string {
  if (raw === maxUint256) return 'MAX'
  return formatAssets(raw, decimals, symbol)
}

export function parseDetailsJson(detailsJson: string): {
  protocol: string | null
  pool: Address | null
} {
  try {
    const details = JSON.parse(detailsJson) as Record<string, unknown>
    const protocol = typeof details.protocol === 'string' ? details.protocol : null
    const pool =
      typeof details.pool === 'string' && /^0x[a-fA-F0-9]{40}$/.test(details.pool)
        ? (details.pool as Address)
        : null
    return { protocol, pool }
  } catch {
    return { protocol: null, pool: null }
  }
}

export function isCleanupAction(value: unknown): value is CleanupAction {
  return typeof value === 'string' && (CLEANUP_ACTIONS as readonly string[]).includes(value)
}
