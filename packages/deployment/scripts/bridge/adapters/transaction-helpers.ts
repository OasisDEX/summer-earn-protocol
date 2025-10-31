import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
// Re-export shared transaction utilities for backward compatibility
export {
  updateIfDifferent,
  waitForTransactionConfirmation,
  writeContractTx,
} from '../../lib/contracts/transactions'
// Re-export bridge validation utilities
export { validateBridgeConfig } from './validation'

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
