import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, getAddress, zeroAddress } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../lib/config/handler'
import { promptForConfigType } from '../lib/infrastructure/prompts'

const REGISTRY_ABI = [
  {
    inputs: [],
    name: 'bridgeRouter',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'executor', type: 'address' }],
    name: 'registerExecutor',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'executor', type: 'address' }],
    name: 'isAuthorizedExecutor',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  // Custom errors (to decode revert reasons)
  { type: 'error', name: 'CallerIsNotGovernor', inputs: [{ name: 'caller', type: 'address' }] },
  { type: 'error', name: 'CallerIsNotKeeper', inputs: [{ name: 'caller', type: 'address' }] },
  { type: 'error', name: 'CallerIsNotGuardian', inputs: [{ name: 'caller', type: 'address' }] },
  {
    type: 'error',
    name: 'CallerIsNotGuardianOrGovernor',
    inputs: [{ name: 'caller', type: 'address' }],
  },
  { type: 'error', name: 'CallerIsNotSuperKeeper', inputs: [{ name: 'caller', type: 'address' }] },
  { type: 'error', name: 'CallerIsNotFoundation', inputs: [{ name: 'caller', type: 'address' }] },
  {
    type: 'error',
    name: 'InvalidAccessManagerAddress',
    inputs: [{ name: 'invalidAddress', type: 'address' }],
  },
  // BaseCrossChainRegistry errors
  { type: 'error', name: 'InvalidChainId', inputs: [{ name: 'invalidChainId', type: 'uint16' }] },
  {
    type: 'error',
    name: 'InvalidChainRelationship',
    inputs: [
      { name: 'sourceChainId', type: 'uint16' },
      { name: 'targetChainId', type: 'uint16' },
      { name: 'currentChainId', type: 'uint16' },
    ],
  },
  {
    type: 'error',
    name: 'InvalidSourceContract',
    inputs: [{ name: 'sourceContract', type: 'address' }],
  },
  {
    type: 'error',
    name: 'InvalidTargetContract',
    inputs: [{ name: 'targetContract', type: 'address' }],
  },
  {
    type: 'error',
    name: 'InvalidRelationshipType',
    inputs: [{ name: 'relationshipType', type: 'bytes32' }],
  },
  {
    type: 'error',
    name: 'UnsupportedRelationshipType',
    inputs: [{ name: 'relationshipType', type: 'bytes32' }],
  },
  {
    type: 'error',
    name: 'RelationshipAlreadyExists',
    inputs: [
      { name: 'sourceContract', type: 'address' },
      { name: 'relationshipType', type: 'bytes32' },
      { name: 'targetChainId', type: 'uint16' },
    ],
  },
  {
    type: 'error',
    name: 'TargetContractAlreadyRegistered',
    inputs: [
      { name: 'targetContract', type: 'address' },
      { name: 'sourceChainId', type: 'uint16' },
      { name: 'targetChainId', type: 'uint16' },
      { name: 'relationshipType', type: 'bytes32' },
      { name: 'existingSource', type: 'address' },
    ],
  },
  {
    type: 'error',
    name: 'RelationshipDoesNotExist',
    inputs: [
      { name: 'sourceContract', type: 'address' },
      { name: 'relationshipType', type: 'bytes32' },
      { name: 'targetChainId', type: 'uint16' },
    ],
  },
  { type: 'error', name: 'AddressZero', inputs: [] },
] as const

function parseExtraAddresses(input: string | undefined): Address[] {
  if (!input) return []
  return input
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.startsWith('0x') && s.length === 42)
    .map((s) => getAddress(s as `0x${string}`))
}

async function ensureExecutor(registry: Address, executor: Address): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()
  const isAlready = (await publicClient.readContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'isAuthorizedExecutor',
    args: [getAddress(executor as `0x${string}`)],
  })) as boolean
  if (isAlready) return false

  const [wallet] = await hre.viem.getWalletClients()
  const hash = await wallet.writeContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'registerExecutor',
    args: [getAddress(executor as `0x${string}`)],
  })
  await publicClient.waitForTransactionReceipt({ hash })
  return true
}

export async function registerExecutors() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const nonInteractive =
    process.argv.includes('--no-prompts') ||
    ['1', 'true'].includes(String(process.env.NON_INTERACTIVE).toLowerCase())

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  const registryAddress = config.deployedContracts.bridge?.crossChainRegistry?.address as Address
  if (!registryAddress) throw new Error('CrossChainRegistry not deployed on this network')

  // Guard: ensure registry.bridgeRouter is configured
  const publicClientForGuard = await hre.viem.getPublicClient()
  const configuredBridgeRouter = (await publicClientForGuard.readContract({
    address: getAddress(registryAddress as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'bridgeRouter',
    args: [],
  })) as Address

  if (configuredBridgeRouter === zeroAddress) {
    console.log(
      kleur
        .red()
        .bold(
          'CrossChainRegistry.bridgeRouter is not set (0x0). Aborting executor registration.\n' +
            'Action required: set the BridgeRouter on this chain using setBridgeRouter(), then re-run this script.',
        ),
    )
    return
  }

  const candidates: Address[] = []

  try {
    const currentChainId = Number((config as BaseConfig).common.chainId)
    const cfgDir = path.resolve(__dirname, '..', '..', 'config', 'cross-chain')
    if (fs.existsSync(cfgDir)) {
      const files = fs
        .readdirSync(cfgDir)
        .filter((f) => f.endsWith('.json'))
        .map((f) => path.join(cfgDir, f))

      for (const file of files) {
        try {
          const raw = fs.readFileSync(file, 'utf8')
          const data = JSON.parse(raw) as {
            sourceChainId?: number
            destinations?: Array<{
              chainId: number
              protocols: Array<{
                protocol: string
                fleetProxyAddress?: string
                crossChainArkAddress?: string
              }>
            }>
          }

          // On source (hub) chain: CrossChainArk calls BridgeRouter → register CrossChainArk
          if (data?.sourceChainId && Number(data.sourceChainId) === currentChainId) {
            for (const dest of data.destinations ?? []) {
              for (const p of dest.protocols ?? []) {
                const addr = p.crossChainArkAddress
                if (addr && addr.startsWith('0x') && addr.length === 42) {
                  const normalized = getAddress(addr as `0x${string}`)
                  if (!candidates.includes(normalized)) candidates.push(normalized)
                }
              }
            }
          }

          // On destination (satellite) chain: FleetProxy calls BridgeRouter → register FleetProxy
          for (const dest of data.destinations ?? []) {
            if (Number(dest.chainId) === currentChainId) {
              for (const p of dest.protocols ?? []) {
                const addr = p.fleetProxyAddress
                if (addr && addr.startsWith('0x') && addr.length === 42) {
                  const normalized = getAddress(addr as `0x${string}`)
                  if (!candidates.includes(normalized)) candidates.push(normalized)
                }
              }
            }
          }
        } catch (err) {
          console.log(kleur.yellow(`Skipped invalid cross-chain config: ${file}`))
        }
      }
    }
  } catch (err) {
    console.log(kleur.red('Failed to load cross-chain executors from config:'), err)
  }

  if (!nonInteractive) {
    const { extra } = await prompts({
      type: 'text',
      name: 'extra',
      message:
        'Optional: enter additional executor addresses (comma-separated 0x addresses), or leave blank:',
    })
    for (const addr of parseExtraAddresses(extra)) {
      if (!candidates.includes(addr)) candidates.push(addr)
    }
  }

  if (candidates.length === 0) {
    console.log(kleur.yellow('No executor addresses provided; nothing to register.'))
    return
  }

  console.log(kleur.green().bold('Registering executors on CrossChainRegistry (local chain)...'))

  let created = 0
  for (const addr of candidates) {
    try {
      const made = await ensureExecutor(registryAddress, addr)
      if (made) {
        created += 1
        console.log(kleur.green(`✓ Registered executor ${addr}`))
      } else {
        console.log(kleur.yellow(`• Executor already registered ${addr}`))
      }
    } catch (err) {
      console.error(kleur.red(`✗ Failed to register executor ${addr}:`), err)
    }
  }

  console.log(kleur.green().bold(`Done. ${created}/${candidates.length} executor(s) registered.`))
}

if (require.main === module) {
  registerExecutors().catch((error) => {
    console.error(kleur.red('Error during executor registration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
