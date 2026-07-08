import path from 'node:path'

import { Address, formatUnits, maxUint256, parseAbi } from 'viem'

import { SafeAbiFunctionFragment } from '../../helpers/safe-tx-builder'

/**
 * Shared pieces of the config-driven fleet-cleanup tooling:
 *  - `gov:cleanup-fleets:init`  (init.ts)          — generates one editable JSON per fleet
 *  - `gov:cleanup-fleets`      (build-batches.ts)  — turns those JSONs into Safe batches
 *
 * Config files live in config/fleet-cleanup/<network>/<FleetName>.json and are the operator's
 * worksheet: every ark defaults to `action: "leave"`; flipping an action and re-running the
 * build script emits one Safe Transaction Builder batch per fleet.
 */

export type CleanupAction = 'leave' | 'socializeLosses' | 'socializeLossesAndRemove' | 'removeArk'

export const CLEANUP_ACTIONS: readonly CleanupAction[] = [
  'leave',
  'socializeLosses',
  'socializeLossesAndRemove',
  'removeArk',
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

export const CURATOR_ROLE_ENUM = 0 // ContractSpecificRoles.CURATOR_ROLE

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
