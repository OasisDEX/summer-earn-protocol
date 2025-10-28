import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, getAddress, isAddressEqual, zeroAddress } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { CrossChainConfig, loadCrossChainConfig } from '../lib/config/cross-chain'
import { getConfigByNetwork } from '../lib/config/handler'
import { promptForAddresses, promptForConfigType, promptYesNo } from '../lib/infrastructure/prompts'

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
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
    ],
    name: 'unregisterRelationship',
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
  {
    inputs: [
      { internalType: 'address', name: 'sourceContract', type: 'address' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'getTargetsForSource',
    outputs: [
      { internalType: 'address[]', name: 'targetContracts', type: 'address[]' },
      { internalType: 'uint16[]', name: 'targetChainIds', type: 'uint16[]' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint16', name: 'sourceChainId', type: 'uint16' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
      { internalType: 'address', name: 'targetContract', type: 'address' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'getSourceForTarget',
    outputs: [{ internalType: 'address', name: 'sourceContract', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'PEER_RELATIONSHIP',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'pure',
    type: 'function',
  },
] as const

async function ensurePeerRelationship(
  registry: Address,
  sourceArk: Address,
  targetFleetProxy: Address,
  sourceChainId: number,
  targetChainId: number,
): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()
  const [wallet] = await hre.viem.getWalletClients()

  const peerRelationshipType = (await publicClient.readContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'PEER_RELATIONSHIP',
    args: [],
  })) as `0x${string}`

  const already = (await publicClient.readContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'isValidCrossChainPair',
    args: [
      getAddress(sourceArk as `0x${string}`),
      getAddress(targetFleetProxy as `0x${string}`),
      Number(sourceChainId),
      Number(targetChainId),
      peerRelationshipType,
    ],
  })) as boolean

  if (already) return false

  // Pre-state: detect stale mappings and offer to unregister
  // 1) If the source already has a target for this targetChainId and it's different, unregister it first
  try {
    const result = (await publicClient.readContract({
      address: getAddress(registry as `0x${string}`),
      abi: REGISTRY_ABI,
      functionName: 'getTargetsForSource',
      args: [getAddress(sourceArk as `0x${string}`), peerRelationshipType],
    })) as [readonly Address[], readonly number[]]

    const targetContracts = result[0] as readonly Address[]
    const targetChains = result[1] as readonly number[]
    const idx = targetChains.findIndex((c) => Number(c) === Number(targetChainId))
    if (idx !== -1) {
      const existingTarget = getAddress(targetContracts[idx] as `0x${string}`)
      if (!isAddressEqual(existingTarget, getAddress(targetFleetProxy as `0x${string}`))) {
        console.log(
          kleur.yellow(
            `    Detected existing target for SOURCE on chain ${targetChainId}: ${existingTarget}. This must be unregistered first.`,
          ),
        )
        const confirmUnreg = await promptYesNo(
          `Unregister mapping for SOURCE ${getAddress(
            sourceArk as `0x${string}`,
          )} on chain ${targetChainId} (current target: ${existingTarget})?`,
        )
        if (!confirmUnreg) {
          return false
        }
        const unregHash1 = await wallet.writeContract({
          address: getAddress(registry as `0x${string}`),
          abi: REGISTRY_ABI,
          functionName: 'unregisterRelationship',
          args: [
            getAddress(sourceArk as `0x${string}`),
            peerRelationshipType,
            Number(targetChainId),
          ],
        })
        await publicClient.waitForTransactionReceipt({ hash: unregHash1 })
        console.log(
          kleur.green(`    ✓ Unregistered stale source mapping for chain ${targetChainId}`),
        )
      }
    }
  } catch {
    // ignore best-effort pre-state lookup
  }

  // 2) If the target is already linked to a different source for this chain pair, offer to unregister that source
  const safeGetSourceForTarget = async (
    srcChainId: number,
    dstChainId: number,
    target: Address,
  ): Promise<Address> => {
    try {
      const relType = (await publicClient.readContract({
        address: getAddress(registry as `0x${string}`),
        abi: REGISTRY_ABI,
        functionName: 'PEER_RELATIONSHIP',
        args: [],
      })) as `0x${string}`

      return (await publicClient.readContract({
        address: getAddress(registry as `0x${string}`),
        abi: REGISTRY_ABI,
        functionName: 'getSourceForTarget',
        args: [
          Number(srcChainId),
          Number(dstChainId),
          getAddress(target as `0x${string}`),
          relType,
        ],
      })) as Address
    } catch {
      return zeroAddress as Address
    }
  }

  const existingSourceForTarget = await safeGetSourceForTarget(
    sourceChainId,
    targetChainId,
    targetFleetProxy,
  )
  if (
    !isAddressEqual(existingSourceForTarget, zeroAddress) &&
    !isAddressEqual(existingSourceForTarget, getAddress(sourceArk as `0x${string}`))
  ) {
    console.log(
      kleur.yellow(
        `    Detected existing source ${existingSourceForTarget} already registered to target ${getAddress(
          targetFleetProxy as `0x${string}`,
        )} for chain pair ${sourceChainId}→${targetChainId}. This must be unregistered first.`,
      ),
    )
    const useDetected = await promptYesNo(
      `Unregister detected stale SOURCE ${existingSourceForTarget} for target ${getAddress(
        targetFleetProxy as `0x${string}`,
      )} (chain ${sourceChainId}→${targetChainId})?`,
    )
    let staleSource = existingSourceForTarget
    if (!useDetected) {
      const [addr] = await promptForAddresses(
        'Enter the stale SOURCE address to unregister for this chain pair (single address):',
      )
      staleSource = getAddress(addr as `0x${string}`)
    }
    const unregHash2 = await wallet.writeContract({
      address: getAddress(registry as `0x${string}`),
      abi: REGISTRY_ABI,
      functionName: 'unregisterRelationship',
      args: [getAddress(staleSource as `0x${string}`), peerRelationshipType, Number(targetChainId)],
    })
    await publicClient.waitForTransactionReceipt({ hash: unregHash2 })
    console.log(
      kleur.green(
        `    ✓ Unregistered stale source ${staleSource} for target ${getAddress(
          targetFleetProxy as `0x${string}`,
        )} (chain ${sourceChainId}→${targetChainId})`,
      ),
    )
  }

  const hash = await wallet.writeContract({
    address: getAddress(registry as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'registerRelationship',
    args: [
      getAddress(sourceArk as `0x${string}`),
      getAddress(targetFleetProxy as `0x${string}`),
      Number(sourceChainId),
      Number(targetChainId),
      peerRelationshipType,
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
        `Registering Ark-Fleet peer relationships on local registry (chainId=${localChainId}) for ${fleetName}...`,
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
        const made = await ensurePeerRelationship(
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
    console.log(kleur.green().bold(`Done. ${created}/${total} peer relationship(s) created.`))
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
