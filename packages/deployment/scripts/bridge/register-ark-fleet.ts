import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, getAddress, keccak256, stringToBytes } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import { CrossChainConfig, loadCrossChainConfig } from '../helpers/cross-chain-config'
import { promptForConfigType } from '../helpers/prompt-helpers'

const REGISTRY_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'sourceContract', type: 'address' },
      { internalType: 'address', name: 'targetContract', type: 'address' },
      { internalType: 'uint16', name: 'sourceChainId', type: 'uint16' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'registerRelationship',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'sourceContract', type: 'address' },
      { internalType: 'address', name: 'targetContract', type: 'address' },
      { internalType: 'uint16', name: 'sourceChainId', type: 'uint16' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'isValidCrossChainPair',
    outputs: [{ internalType: 'bool', name: 'isValid', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

const ARK_FLEET_REL = keccak256(stringToBytes('ARK_FLEET_RELATIONSHIP'))

async function ensureArkFleetRelationship(
  registry: Address,
  sourceArk: Address,
  targetFleetProxy: Address,
  sourceChainId: number,
  targetChainId: number,
): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()
  const [wallet] = await hre.viem.getWalletClients()

  const already = (await publicClient.readContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'isValidCrossChainPair',
    args: [
      getAddress(sourceArk as `0x${string}`),
      getAddress(targetFleetProxy as `0x${string}`),
      Number(sourceChainId),
      Number(targetChainId),
      ARK_FLEET_REL,
    ],
  })) as boolean

  if (already) return false

  const hash = await wallet.writeContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'registerRelationship',
    args: [
      getAddress(sourceArk as `0x${string}`),
      getAddress(targetFleetProxy as `0x${string}`),
      Number(sourceChainId),
      Number(targetChainId),
      ARK_FLEET_REL,
    ],
  })
  await publicClient.waitForTransactionReceipt({ hash })
  return true
}

function listCrossChainConfigs(): string[] {
  const dir = path.join(process.cwd(), 'config', 'cross-chain')
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .sort()
}

async function chooseFleetConfig(): Promise<string | null> {
  const files = listCrossChainConfigs()
  if (files.length === 0) {
    console.log(kleur.yellow('No cross-chain config files found under config/cross-chain'))
    return null
  }

  const { selected } = await prompts({
    type: 'select',
    name: 'selected',
    message: 'Select a fleet cross-chain config:',
    choices: files.map((f) => ({ title: f, value: f })),
  })
  return selected || null
}

export async function registerArkFleetRelationships() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const localConfig = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  const registryAddress = localConfig.deployedContracts.bridge?.crossChainRegistry
    ?.address as Address
  if (!registryAddress) throw new Error('CrossChainRegistry not deployed on this network')

  const localChainId = Number(localConfig.common.chainId)

  const chosen = await chooseFleetConfig()
  if (!chosen) return

  const fleetName = chosen.replace(/\.json$/, '')
  const cc: CrossChainConfig | null = loadCrossChainConfig(fleetName)
  if (!cc) throw new Error(`Failed to load cross-chain config for ${fleetName}`)

  if (!cc.sourceChainId || cc.sourceChainId === 0) {
    console.log(kleur.yellow('sourceChainId missing in cross-chain config; make sure it is set.'))
  }

  console.log(
    kleur
      .green()
      .bold(
        `Registering ARK_FLEET relationships on local registry (chainId=${localChainId}) for ${fleetName}...`,
      ),
  )

  let total = 0
  let created = 0

  for (const dest of cc.destinations) {
    for (const protocol of dest.protocols) {
      const ark = protocol.crossChainArkAddress
      const fleetProxy = protocol.fleetProxyAddress

      if (!ark || !fleetProxy) continue

      // Register only if this chain matches one side of the pair
      if (localChainId !== cc.sourceChainId && localChainId !== dest.chainId) continue

      total += 1

      // Always use (sourceChainId -> destChainId) orientation
      const sourceChainId = cc.sourceChainId
      const targetChainId = dest.chainId

      console.log(
        `- ${protocol.protocol}: ${kleur.blue(String(sourceChainId))} ARK -> ${kleur.blue(
          String(targetChainId),
        )} FLEET (ark=${ark}, fleet=${fleetProxy})`,
      )

      try {
        const made = await ensureArkFleetRelationship(
          registryAddress,
          ark as Address,
          fleetProxy as Address,
          sourceChainId,
          targetChainId,
        )
        if (made) {
          created += 1
          console.log(kleur.green('  ✓ Registered'))
        } else {
          console.log(kleur.yellow('  • Already registered'))
        }
      } catch (err) {
        console.error(kleur.red('  ✗ Failed to register:'), err)
      }
    }
  }

  if (total === 0) {
    console.log(
      kleur.yellow(
        'Nothing to register on this chain. Ensure you run this script on the source and each destination chain.',
      ),
    )
  } else {
    console.log(kleur.green().bold(`Done. ${created}/${total} relationship(s) created.`))
  }

  console.log(
    kleur.yellow(
      'Tip: run on both the source chain and each destination chain to mirror relationships across registries.',
    ),
  )
}

if (require.main === module) {
  registerArkFleetRelationships().catch((error) => {
    console.error(kleur.red('Error during ARK_FLEET relationship registration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
