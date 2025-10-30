import hre from 'hardhat'
import kleur from 'kleur'
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
    inputs: [{ internalType: 'address', name: 'newBridgeRouter', type: 'address' }],
    name: 'setBridgeRouter',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export async function setBridgeRouterOnRegistry() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const nonInteractive =
    process.argv.includes('--no-prompts') ||
    ['1', 'true'].includes(String(process.env.NON_INTERACTIVE).toLowerCase())

  // Config selection (interactive unless NON_INTERACTIVE)
  const useBummerConfig = nonInteractive ? true : await promptForConfigType()
  const localConfig = getConfigByNetwork(
    network,
    { common: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  const registryAddress = localConfig.deployedContracts.bridge?.crossChainRegistry
    ?.address as Address
  // Allow override via CLI or env; fallback to config
  const cliOverrideArg = process.argv.find((a) => a.startsWith('--address='))
  const overrideFromCli = cliOverrideArg ? (cliOverrideArg.split('=')[1] || '').trim() : ''
  const overrideFromEnv = (process.env.BRIDGE_ROUTER_ADDRESS || '').trim()
  const desiredBridgeRouterRaw =
    overrideFromCli ||
    overrideFromEnv ||
    (localConfig.deployedContracts.bridge?.bridgeRouter?.address as string | undefined) ||
    ''
  const bridgeRouterAddress = desiredBridgeRouterRaw as Address

  if (!registryAddress) throw new Error('CrossChainRegistry not deployed on this network')
  if (!bridgeRouterAddress) throw new Error('BridgeRouter address not provided or found in config')

  let normalizedDesired: Address
  try {
    normalizedDesired = getAddress(bridgeRouterAddress as `0x${string}`)
  } catch {
    throw new Error(`Invalid BridgeRouter address: ${String(bridgeRouterAddress)}`)
  }
  if (normalizedDesired === zeroAddress) throw new Error('BridgeRouter cannot be zero address')

  const publicClient = await hre.viem.getPublicClient()
  const current = (await publicClient.readContract({
    address: getAddress(registryAddress as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'bridgeRouter',
  })) as Address

  if (current !== zeroAddress && current.toLowerCase() === normalizedDesired.toLowerCase()) {
    console.log(
      kleur.green('✓ CrossChainRegistry.bridgeRouter is already set to the expected address.'),
    )
    return
  }

  const [wallet] = await hre.viem.getWalletClients()
  console.log(kleur.green(`Setting CrossChainRegistry.bridgeRouter to ${normalizedDesired}...`))
  const hash = await wallet.writeContract({
    address: getAddress(registryAddress as `0x${string}`),
    abi: REGISTRY_ABI,
    functionName: 'setBridgeRouter',
    args: [normalizedDesired],
  })
  await publicClient.waitForTransactionReceipt({ hash })
  console.log(kleur.green('✓ BridgeRouter set on CrossChainRegistry'))
}

if (require.main === module) {
  setBridgeRouterOnRegistry().catch((error) => {
    console.error(kleur.red('Error setting bridge router on CrossChainRegistry:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
