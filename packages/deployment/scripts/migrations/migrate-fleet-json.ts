/**
 * One-time migration script to convert legacy fleet config and deployment JSON
 * to the canonical v2 schema format (schemaVersion: 2).
 *
 * Run from packages/deployment: pnpm tsx scripts/migrations/migrate-fleet-json.ts
 */

import fs from 'node:fs'
import path from 'node:path'
import {
  FLEET_SCHEMA_VERSION,
  FleetConfigFileSchema,
  FleetDeploymentFileSchema,
  FleetDetailsSchema,
} from '../helpers/zod-schemas'

const DEPLOYMENT_ROOT = path.resolve(__dirname, '..', '..')
const CONFIG_FLEETS_DIR = path.join(DEPLOYMENT_ROOT, 'config', 'fleets')
const DEPLOYMENTS_FLEETS_DIR = path.join(DEPLOYMENT_ROOT, 'deployments', 'fleets')

interface NetworkConfig {
  chainId: number
  tokens: Record<string, string>
}

function loadBaseConfig(): Record<string, NetworkConfig> {
  const indexPath = path.join(DEPLOYMENT_ROOT, 'config', 'index.json')
  const raw = JSON.parse(fs.readFileSync(indexPath, 'utf8')) as Record<
    string,
    { common?: { chainId?: string }; tokens?: Record<string, string> }
  >
  const result: Record<string, NetworkConfig> = {}
  for (const [network, netConfig] of Object.entries(raw)) {
    if (!netConfig?.common?.chainId || !netConfig?.tokens) continue
    result[network] = {
      chainId: parseInt(netConfig.common.chainId, 10),
      tokens: netConfig.tokens,
    }
  }
  return result
}

function getAssetAddress(
  assetSymbol: string,
  network: string,
  baseConfig: Record<string, NetworkConfig>,
): string {
  const net = baseConfig[network]
  if (!net) {
    throw new Error(`Unknown network: ${network}`)
  }
  const key = assetSymbol.toLowerCase()
  const addr = net.tokens[key]
  if (!addr || addr === '0x0000000000000000000000000000000000000000') {
    throw new Error(`No token address for ${assetSymbol} on ${network}`)
  }
  return addr
}

function synthesizeDetails(
  raw: { fleetName: string; assetSymbol: string; network: string; details?: unknown },
  baseConfig: Record<string, NetworkConfig>,
): { name: string; chainId: number; asset: string; assetSymbol: string; type: 'protocol' | 'dao' } {
  const network = raw.network
  const net = baseConfig[network]
  if (!net) {
    throw new Error(`Unknown network: ${network}`)
  }
  const isDao =
    typeof raw.details === 'object' &&
    raw.details !== null &&
    'type' in raw.details &&
    (raw.details as { type?: string }).type === 'dao'
  return {
    name:
      (typeof raw.details === 'object' && raw.details !== null && 'name' in raw.details
        ? (raw.details as { name?: string }).name
        : null) ?? raw.fleetName,
    chainId: net.chainId,
    asset: getAssetAddress(raw.assetSymbol, network, baseConfig),
    assetSymbol: raw.assetSymbol,
    type: isDao ? 'dao' : 'protocol',
  }
}

function migrateConfigFile(filePath: string, baseConfig: Record<string, NetworkConfig>): void {
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Record<string, unknown>
  const isBummer =
    (typeof raw.isBummer === 'boolean' && raw.isBummer) ||
    path.basename(filePath).includes('.bummer.')

  let details: {
    name: string
    chainId: number
    asset: string
    assetSymbol: string
    type: 'protocol' | 'dao'
  }
  if (
    typeof raw.details === 'object' &&
    raw.details !== null &&
    'type' in raw.details &&
    'chainId' in raw.details &&
    'asset' in raw.details &&
    'assetSymbol' in raw.details
  ) {
    const d = raw.details as Record<string, unknown>
    details = FleetDetailsSchema.parse({
      name: d.name,
      chainId: typeof d.chainId === 'string' ? parseInt(d.chainId, 10) : d.chainId,
      asset: d.asset,
      assetSymbol: d.assetSymbol,
      type: d.type,
    })
  } else {
    details = synthesizeDetails(
      {
        fleetName: String(raw.fleetName ?? ''),
        assetSymbol: String(raw.assetSymbol ?? ''),
        network: String(raw.network ?? ''),
        details: raw.details,
      },
      baseConfig,
    )
  }

  const migrated: Record<string, unknown> = {
    schemaVersion: FLEET_SCHEMA_VERSION,
    fleetName: raw.fleetName,
    isBummer,
    symbol: raw.symbol,
    assetSymbol: raw.assetSymbol,
    initialMinimumBufferBalance: raw.initialMinimumBufferBalance,
    initialRebalanceCooldown: raw.initialRebalanceCooldown,
    depositCap: raw.depositCap,
    initialTipRate: raw.initialTipRate,
    network: raw.network,
    details,
    arks: Array.isArray(raw.arks) ? raw.arks : [],
  }
  if (raw.curator) migrated.curator = raw.curator
  if (raw.keeper) migrated.keeper = raw.keeper
  const rtw = raw.rewardTokens as unknown[] | undefined
  if (Array.isArray(rtw) && rtw.length > 0) migrated.rewardTokens = raw.rewardTokens
  const rtwAmt = raw.rewardAmounts as unknown[] | undefined
  if (Array.isArray(rtwAmt) && rtwAmt.length > 0) migrated.rewardAmounts = raw.rewardAmounts
  if (typeof raw.rewardsDuration === 'number' && raw.rewardsDuration > 0) {
    migrated.rewardsDuration = raw.rewardsDuration
  }
  if (raw.bridgeAmount) migrated.bridgeAmount = raw.bridgeAmount
  if (raw.sipNumber) migrated.sipNumber = raw.sipNumber
  if (raw.discourseURL) migrated.discourseURL = raw.discourseURL

  const parsed = FleetConfigFileSchema.safeParse(migrated)
  if (!parsed.success) {
    throw new Error(`Config migration failed for ${filePath}: ${parsed.error.message}`)
  }

  const canonicalKeys = [
    'schemaVersion',
    'fleetName',
    'isBummer',
    'symbol',
    'assetSymbol',
    'initialMinimumBufferBalance',
    'initialRebalanceCooldown',
    'depositCap',
    'initialTipRate',
    'network',
    'details',
    'arks',
    'curator',
    'keeper',
    'rewardTokens',
    'rewardAmounts',
    'rewardsDuration',
    'bridgeAmount',
    'sipNumber',
    'discourseURL',
  ] as const
  const ordered: Record<string, unknown> = {}
  for (const k of canonicalKeys) {
    if (k in parsed.data && parsed.data[k as keyof typeof parsed.data] !== undefined) {
      ordered[k] = parsed.data[k as keyof typeof parsed.data]
    }
  }
  fs.writeFileSync(filePath, JSON.stringify(ordered, null, 2))
  console.log(`Migrated config: ${path.basename(filePath)}`)
}

function migrateDeploymentFile(
  filePath: string,
  baseConfig: Record<string, NetworkConfig>,
  configsByKey: Map<string, { details: unknown }>,
): void {
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Record<string, unknown>
  const fleetName = String(raw.fleetName ?? '')
  const network = String(raw.network ?? '')
  const assetSymbol = String(raw.assetSymbol ?? '')
  const isBummer =
    (typeof raw.isBummer === 'boolean' && raw.isBummer) ||
    path.basename(filePath).toLowerCase().includes('bummer') ||
    fleetName.toLowerCase().includes('bummer')

  let details: {
    name: string
    chainId: number
    asset: string
    assetSymbol: string
    type: 'protocol' | 'dao'
  }
  const configKey = `${fleetName}::${network}`
  const matchingConfig = configsByKey.get(configKey)
  if (matchingConfig?.details && typeof matchingConfig.details === 'object') {
    details = FleetDetailsSchema.parse(matchingConfig.details)
  } else if (
    typeof raw.details === 'object' &&
    raw.details !== null &&
    'type' in raw.details &&
    'chainId' in raw.details &&
    'asset' in raw.details &&
    'assetSymbol' in raw.details
  ) {
    const d = raw.details as Record<string, unknown>
    details = FleetDetailsSchema.parse({
      name: d.name,
      chainId: typeof d.chainId === 'string' ? parseInt(d.chainId, 10) : d.chainId,
      asset: d.asset,
      assetSymbol: d.assetSymbol,
      type: d.type,
    })
  } else {
    details = synthesizeDetails(
      { fleetName, assetSymbol, network, details: raw.details },
      baseConfig,
    )
  }

  const migrated: Record<string, unknown> = {
    schemaVersion: FLEET_SCHEMA_VERSION,
    fleetName: raw.fleetName,
    isBummer,
    fleetSymbol: raw.fleetSymbol ?? raw.symbol,
    assetSymbol: raw.assetSymbol,
    fleetAddress: raw.fleetAddress,
    bufferArkAddress: raw.bufferArkAddress,
    network: raw.network,
    arks: Array.isArray(raw.arks) ? raw.arks : [],
    details,
  }
  if (raw.initialMinimumBufferBalance)
    migrated.initialMinimumBufferBalance = raw.initialMinimumBufferBalance
  if (raw.initialRebalanceCooldown) migrated.initialRebalanceCooldown = raw.initialRebalanceCooldown
  if (raw.depositCap) migrated.depositCap = raw.depositCap
  if (raw.initialTipRate) migrated.initialTipRate = raw.initialTipRate

  const parsed = FleetDeploymentFileSchema.safeParse(migrated)
  if (!parsed.success) {
    throw new Error(`Deployment migration failed for ${filePath}: ${parsed.error.message}`)
  }

  const canonicalKeys = [
    'schemaVersion',
    'fleetName',
    'isBummer',
    'fleetSymbol',
    'assetSymbol',
    'fleetAddress',
    'bufferArkAddress',
    'network',
    'arks',
    'initialMinimumBufferBalance',
    'initialRebalanceCooldown',
    'depositCap',
    'initialTipRate',
    'details',
  ] as const
  const ordered: Record<string, unknown> = {}
  for (const k of canonicalKeys) {
    if (k in parsed.data && parsed.data[k as keyof typeof parsed.data] !== undefined) {
      ordered[k] = parsed.data[k as keyof typeof parsed.data]
    }
  }
  fs.writeFileSync(filePath, JSON.stringify(ordered, null, 2))
  console.log(`Migrated deployment: ${path.basename(filePath)}`)
}

function main(): void {
  console.log('Loading base config...')
  const baseConfig = loadBaseConfig()

  console.log('\nMigrating fleet configs...')
  const configFiles = fs.readdirSync(CONFIG_FLEETS_DIR).filter((f) => f.endsWith('.json'))
  const configsByKey = new Map<string, { details: unknown }>()

  for (const file of configFiles) {
    const filePath = path.join(CONFIG_FLEETS_DIR, file)
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Record<string, unknown>
    migrateConfigFile(filePath, baseConfig)
    const migrated = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Record<string, unknown>
    configsByKey.set(`${migrated.fleetName}::${migrated.network}`, {
      details: migrated.details,
    })
  }

  console.log('\nMigrating fleet deployments...')
  const deploymentFiles = fs
    .readdirSync(DEPLOYMENTS_FLEETS_DIR)
    .filter((f) => f.endsWith('_deployment.json'))

  for (const file of deploymentFiles) {
    migrateDeploymentFile(path.join(DEPLOYMENTS_FLEETS_DIR, file), baseConfig, configsByKey)
  }

  console.log('\nMigration complete.')
}

main()
