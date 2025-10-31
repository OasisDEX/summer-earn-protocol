import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress, isAddressEqual, zeroAddress } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../lib/config/handler'
import { promptForConfigType } from '../../lib/infrastructure/prompts'

type NetworkConfigs = Record<string, any>

const REGISTRY_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'adapterA', type: 'address' },
      { internalType: 'address', name: 'adapterB', type: 'address' },
      { internalType: 'uint16', name: 'chainA', type: 'uint16' },
      { internalType: 'uint16', name: 'chainB', type: 'uint16' },
    ],
    name: 'registerAdapterPeerPair',
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
      { internalType: 'address', name: 'sourceAdapter', type: 'address' },
      { internalType: 'address', name: 'targetAdapter', type: 'address' },
      { internalType: 'uint16', name: 'sourceChainId', type: 'uint16' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
    ],
    name: 'isValidAdapterPeer',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'sourceAdapter', type: 'address' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
    ],
    name: 'getAdapterPeer',
    outputs: [{ internalType: 'address', name: 'targetAdapter', type: 'address' }],
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

async function ensurePeerPair(
  registryAddress: Address,
  adapterA: Address,
  adapterB: Address,
  chainA: number,
  chainB: number,
): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()
  const [wallet] = await hre.viem.getWalletClients()

  console.log(
    kleur.gray(
      `  • Debug: registry=${getAddress(registryAddress as `0x${string}`)} adapterA=${getAddress(
        adapterA as `0x${string}`,
      )} (chain ${chainA}) ↔ adapterB=${getAddress(adapterB as `0x${string}`)} (chain ${chainB})`,
    ),
  )

  // Check if the peer pair is already registered
  const isAlreadyValid = (await publicClient.readContract({
    address: getAddress(registryAddress as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'isValidAdapterPeer',
    args: [
      getAddress(adapterA as `0x${string}`),
      getAddress(adapterB as `0x${string}`),
      Number(chainA),
      Number(chainB),
    ],
  })) as boolean

  if (isAlreadyValid) {
    console.log(kleur.gray(`    already registered`))
    return false
  }

  // Register the bidirectional peer pair
  const hash = await wallet.writeContract({
    address: getAddress(registryAddress as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'registerAdapterPeerPair',
    args: [
      getAddress(adapterA as `0x${string}`),
      getAddress(adapterB as `0x${string}`),
      Number(chainA),
      Number(chainB),
    ],
  })
  await publicClient.waitForTransactionReceipt({ hash })

  console.log(kleur.gray(`    ✓ registered peer pair`))
  return true
}

async function registerPeersForAdapter(
  adapterLabel: 'layerZero' | 'stargate',
  localConfig: BaseConfig,
  allConfigs: NetworkConfigs,
): Promise<void> {
  const registryAddress = localConfig.deployedContracts.bridge?.crossChainRegistry
    ?.address as Address
  const localChainId = Number(localConfig.common.chainId)
  const localAdapter = (localConfig.deployedContracts.bridge?.adapters as any)?.[adapterLabel]
    ?.address as Address | undefined

  if (!registryAddress) throw new Error('CrossChainRegistry address missing in local config')
  if (!localAdapter) {
    console.log(
      kleur.yellow(`No ${adapterLabel} adapter deployed on this network, skipping ${adapterLabel}`),
    )
    return
  }

  // Normalize and guard against zero address for local adapter
  let normalizedLocalAdapter: Address
  try {
    normalizedLocalAdapter = getAddress(localAdapter as `0x${string}`)
  } catch {
    console.log(
      kleur.yellow(
        `Invalid ${adapterLabel} adapter address on local chain (${String(localAdapter)}), skipping ${adapterLabel}`,
      ),
    )
    return
  }
  if (isAddressEqual(normalizedLocalAdapter, zeroAddress)) {
    console.log(
      kleur.yellow(
        `Local ${adapterLabel} adapter is zero address, skipping ${adapterLabel} peer registration`,
      ),
    )
    return
  }

  console.log(
    kleur.cyan(
      `Local registry=${getAddress(registryAddress as `0x${string}`)} chainId=${localChainId} ${adapterLabel}Adapter=${normalizedLocalAdapter}`,
    ),
  )

  const targetEntries = Object.entries(allConfigs).filter(([network, cfg]) => {
    if (!cfg?.deployedContracts?.bridge?.adapters?.[adapterLabel]?.address) return false
    if (!cfg?.common?.chainId) return false
    // Skip self
    return Number(cfg.common.chainId) !== localChainId
  }) as Array<[string, BaseConfig & any]>

  if (targetEntries.length === 0) {
    console.log(kleur.yellow(`No counterpart ${adapterLabel} adapters found, skipping`))
    return
  }

  console.log(
    kleur.cyan(
      `Registering ${adapterLabel} peers for ${targetEntries.length} target chain(s) on local registry...`,
    ),
  )

  for (const [targetNetwork, targetConfig] of targetEntries) {
    try {
      const targetAdapter = targetConfig.deployedContracts.bridge!.adapters![adapterLabel]!
        .address as Address
      const targetChainId = Number(targetConfig.common.chainId)

      console.log(
        `- ${adapterLabel} ${kleur.blue(String(localChainId))} <-> ${kleur.blue(
          String(targetChainId),
        )} (${targetNetwork})`,
      )

      // Normalize and guard against zero/invalid target adapter
      let normalizedTargetAdapter: Address
      try {
        normalizedTargetAdapter = getAddress(targetAdapter as `0x${string}`)
      } catch {
        console.log(
          kleur.yellow(
            `  • Skipping: target ${adapterLabel} adapter address is invalid (${String(targetAdapter)})`,
          ),
        )
        continue
      }
      if (isAddressEqual(normalizedTargetAdapter, zeroAddress)) {
        console.log(
          kleur.yellow(
            `  • Skipping: target ${adapterLabel} adapter is zero address on chain ${targetChainId}`,
          ),
        )
        continue
      }

      const created = await ensurePeerPair(
        registryAddress,
        normalizedLocalAdapter,
        normalizedTargetAdapter,
        localChainId,
        targetChainId,
      )
      if (created) {
        console.log(kleur.green(`  ✓ Registered peer pair`))
      } else {
        console.log(kleur.yellow(`  • Peer pair already registered`))
      }
    } catch (err) {
      console.error(kleur.red(`  ✗ Failed for ${targetNetwork}:`), err)
    }
  }
}

export async function registerAdapterPeers() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()

  const localConfig = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  const allConfigs = getConfigByNetwork('all', { common: true }, useBummerConfig) as NetworkConfigs

  if (!localConfig?.deployedContracts?.bridge?.crossChainRegistry?.address) {
    throw new Error('CrossChainRegistry not deployed on this network')
  }

  console.log(
    kleur.green().bold('Registering adapter peers via CrossChainRegistry (local chain)...'),
  )

  // Handle LayerZero peers if adapters exist
  await registerPeersForAdapter('layerZero', localConfig, allConfigs)
  // Handle Stargate peers if adapters exist
  await registerPeersForAdapter('stargate', localConfig, allConfigs)

  console.log(kleur.green().bold('Peer registration completed.'))
  console.log(
    kleur.yellow(
      'Note: run this on each chain to ensure both registries contain mirrored relationships.',
    ),
  )
}

if (require.main === module) {
  registerAdapterPeers().catch((error) => {
    console.error(kleur.red('Error during adapter peer registration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
