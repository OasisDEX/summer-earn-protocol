import hre from 'hardhat'
import kleur from 'kleur'
import { Abi, Address, WalletClient, getAddress, decodeErrorResult } from 'viem'
import { isTenderlyVirtualTestnet } from '../infrastructure/tenderly'

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

/**
 * Wait for pending transactions to be confirmed
 */
export async function waitForPendingTransactions(
  requiredConfirmations = 5,
  checkIntervalMs = 5000,
  maxAttempts = 24,
): Promise<void> {
  // Check if we're on Tenderly virtual testnet
  const isTenderly = isTenderlyVirtualTestnet()

  if (isTenderly) {
    console.log(kleur.yellow('Detected Tenderly virtual testnet, skipping confirmation wait'))
    return
  }

  const [deployer] = await hre.viem.getWalletClients()
  const provider = await hre.viem.getPublicClient()
  const address = deployer.account.address

  console.log(kleur.yellow(`Checking for pending transactions from ${address}...`))

  let attempts = 0
  while (attempts < maxAttempts) {
    try {
      // Get the current nonce
      const currentNonce = await provider.getTransactionCount({ address })

      // Get the pending nonce
      const pendingNonce = await provider.getTransactionCount({
        address,
        blockTag: 'pending',
      })

      // First check if there are any pending transactions
      if (currentNonce !== pendingNonce) {
        console.log(
          kleur.yellow(
            `Waiting for ${pendingNonce - currentNonce} transactions to be mined (${attempts + 1}/${maxAttempts})...`,
          ),
        )
        await new Promise((resolve) => setTimeout(resolve, checkIntervalMs))
        attempts++
        continue
      }

      // Now check if recent transactions have enough confirmations
      const latestBlock = await provider.getBlockNumber()

      // Check transactions from recent blocks to see if any are from our deployer
      let hasRecentTransactions = false

      // Look back a few blocks to find recent transactions from this address
      for (let i = 0; i < Math.min(5, Number(latestBlock)); i++) {
        const blockNumber = latestBlock - BigInt(i)
        try {
          const block = await provider.getBlock({ blockNumber, includeTransactions: true })

          if (block.transactions) {
            for (const tx of block.transactions) {
              if (typeof tx === 'object' && tx.from?.toLowerCase() === address.toLowerCase()) {
                const confirmations = Number(latestBlock - blockNumber) + 1
                if (confirmations < requiredConfirmations) {
                  console.log(
                    kleur.yellow(
                      `Transaction ${tx.hash} has ${confirmations}/${requiredConfirmations} confirmations (${attempts + 1}/${maxAttempts})...`,
                    ),
                  )
                  hasRecentTransactions = true
                  break
                }
              }
            }
          }
        } catch (error) {
          // If we can't get a block, just continue
          continue
        }

        if (hasRecentTransactions) break
      }

      if (!hasRecentTransactions) {
        console.log(
          kleur.green('All recent transactions have sufficient confirmations, continuing...'),
        )
        return
      }

      // Wait for the specified interval
      await new Promise((resolve) => setTimeout(resolve, checkIntervalMs))
      attempts++
    } catch (error) {
      console.error(kleur.red('Error checking pending transactions:'), error)
      attempts++
      // Continue anyway, but log the error
    }
  }

  console.log(kleur.yellow('Max wait time reached, proceeding anyway...'))
}
