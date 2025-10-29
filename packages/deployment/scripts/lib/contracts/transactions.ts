import hre from 'hardhat'
import kleur from 'kleur'
import { Abi, Address, WalletClient, getAddress, decodeErrorResult } from 'viem'

/**
 * Custom error for contract transaction failures
 */
export class ContractTransactionError extends Error {
  constructor(message: string, public readonly originalError?: unknown) {
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
  errorAbi?: Abi,
): Promise<string> {
  try {
    const hash = await walletClient.writeContract({
      address: getAddress(contractAddress as `0x${string}`),
      abi,
      functionName: functionName as any,
      args,
    })
    return hash
  } catch (error: unknown) {
    let errorMessage = `Failed to execute ${functionName}: ${error instanceof Error ? error.message : 'Unknown error'}`

    // Try to decode the error if error ABI is provided
    if (errorAbi && error) {
      try {
        // Viem errors may have different structures - check for data property
        let errorData: `0x${string}` | undefined

        if (error && typeof error === 'object') {
          // Check for direct data property
          if ('data' in error && typeof error.data === 'string' && error.data.startsWith('0x')) {
            errorData = error.data as `0x${string}`
          }
          // Check for nested data in cause (common in viem BaseError)
          else if ('cause' in error && error.cause && typeof error.cause === 'object') {
            if ('data' in error.cause && typeof error.cause.data === 'string' && error.cause.data.startsWith('0x')) {
              errorData = error.cause.data as `0x${string}`
            }
          }
          // Check for nested error in shortMessage (viem error format)
          else if ('shortMessage' in error && typeof error.shortMessage === 'string') {
            // Extract error data from shortMessage if it contains a hex string
            const hexMatch = error.shortMessage.match(/0x[a-fA-F0-9]+/)
            if (hexMatch) {
              errorData = hexMatch[0] as `0x${string}`
            }
          }
        }

        if (errorData) {
          const decoded = decodeErrorResult({
            abi: errorAbi,
            data: errorData,
          })

          // Format decoded error with parameters if available
          if (decoded.args && decoded.args.length > 0) {
            const argsStr = decoded.args
              .map((arg) => {
                if (typeof arg === 'bigint') {
                  return arg.toString()
                }
                if (typeof arg === 'object' && arg !== null) {
                  return JSON.stringify(arg)
                }
                return String(arg)
              })
              .join(', ')
            errorMessage = `Failed to execute ${functionName}: ${decoded.errorName}(${argsStr})`
          } else {
            errorMessage = `Failed to execute ${functionName}: ${decoded.errorName}()`
          }
        }
      } catch (decodeError) {
        // If decoding fails, fall back to original error message
        // This is expected if the error signature doesn't match
      }
    }

    throw new ContractTransactionError(errorMessage, error)
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
