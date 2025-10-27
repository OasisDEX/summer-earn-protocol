import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { AdapterConfigurationError } from './errors'

/**
 * Write a contract transaction with consistent error handling
 */
export async function writeContractTx(
  walletClient: any,
  contractAddress: Address,
  abi: readonly any[],
  functionName: string,
  args: readonly any[],
): Promise<string> {
  try {
    const hash = await walletClient.writeContract({
      address: getAddress(contractAddress as `0x${string}`),
      abi,
      functionName,
      args,
    })
    return hash
  } catch (error) {
    throw new AdapterConfigurationError(
      `Failed to execute ${functionName}: ${error instanceof Error ? error.message : 'Unknown error'}`,
    )
  }
}

/**
 * Check if a value needs updating and execute update if different
 */
export async function updateIfDifferent<T>(
  contract: any,
  walletClient: any,
  readFunction: string,
  currentValue: T,
  expectedValue: T,
  updateFunction: () => Promise<string>,
  logMessage: string,
): Promise<boolean> {
  if (currentValue !== expectedValue) {
    console.log(logMessage)
    const hash = await updateFunction()
    console.log(kleur.green(`Update successful, tx: ${hash}`))
    return true
  } else {
    console.log(kleur.yellow('Value already correct, skipping update'))
    return false
  }
}

/**
 * Wait for transaction confirmation
 */
export async function waitForTransactionConfirmation(hash: string): Promise<void> {
  const publicClient = await hre.viem.getPublicClient()
  await publicClient.waitForTransactionReceipt({ hash })
}

/**
 * Validate that required config fields exist
 */
export function validateBridgeConfig(config: BaseConfig): void {
  if (!config.deployedContracts.bridge?.crossChainRegistry?.address) {
    throw new AdapterConfigurationError('CrossChainRegistry address not found in config')
  }
  if (!config.deployedContracts.gov?.protocolAccessManager?.address) {
    throw new AdapterConfigurationError('ProtocolAccessManager address not found in config')
  }
  if (!config.common.layerZero?.lzEndpoint) {
    throw new AdapterConfigurationError('LayerZero endpoint not configured')
  }
}

/**
 * Check if adapter is already registered with bridge router
 */
export async function isAdapterRegistered(
  bridgeRouterAddress: Address,
  adapterAddress: Address,
): Promise<boolean> {
  try {
    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(bridgeRouterAddress as `0x${string}`),
    )

    return Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(adapterAddress as `0x${string}`)]),
    )
  } catch (error) {
    console.error(kleur.red('Error checking if adapter is registered:'), error)
    return false
  }
}
