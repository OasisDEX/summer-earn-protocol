import hre from 'hardhat'
import kleur from 'kleur'
import { Abi, Address, WalletClient, getAddress } from 'viem'

/**
 * Custom error for contract transaction failures
 */
export class ContractTransactionError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ContractTransactionError'
  }
}

/**
 * Write a contract transaction with consistent error handling
 */
export async function writeContractTx<TAbi extends Abi>(
  walletClient: WalletClient,
  contractAddress: Address,
  abi: TAbi,
  functionName: string,
  args: readonly unknown[],
): Promise<string> {
  try {
    const hash = await walletClient.writeContract({
      address: getAddress(contractAddress as `0x${string}`),
      abi,
      functionName: functionName as any,
      args,
    })
    return hash
  } catch (error) {
    throw new ContractTransactionError(
      `Failed to execute ${functionName}: ${error instanceof Error ? error.message : 'Unknown error'}`,
    )
  }
}

/**
 * Check if a value needs updating and execute update if different
 */
export async function updateIfDifferent<T>(
  contract: any,
  walletClient: WalletClient,
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
