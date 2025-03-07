import { addressToBytes32, Options } from '@layerzerolabs/lz-v2-utilities'
import kleur from 'kleur'
import { Address, encodeFunctionData, Hex, PublicClient } from 'viem'
import SummerTokenABI from '../../artifacts/src/contracts/SummerToken.sol/SummerToken.json'

/**
 * Prepares actions for bridging tokens across chains using LayerZero
 * Aggregates amounts for each token to minimize the number of cross-chain transactions
 * Includes fee estimation with safety buffer for governance timelock delays
 *
 * @param bridgeContractAddress The address of the bridge contract (OFT)
 * @param amount The amount to bridge
 * @param destinationChainEid The LayerZero endpoint ID of the destination chain
 * @param recipient Recipient address on the destination chain (defaults to executing address)
 * @param refundAddress Refund address for excess fees (defaults to executing address)
 * @param publicClient The public client to use for the transaction
 * @param safetyMultiplier The safety multiplier for the bridge transaction
 * @returns Object containing targets, values, and calldatas for governance proposal
 */
export async function prepareBridgeTransaction(
  bridgeContractAddress: Address,
  amount: bigint,
  destinationChainEid: number,
  recipient: Address,
  refundAddress: Address,
  publicClient: PublicClient,
  safetyMultiplier: number = 1.5,
): Promise<{ targets: Address[]; values: bigint[]; calldatas: Hex[] }> {
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  console.log(
    kleur.yellow(
      `- Preparing bridge transaction for token ${bridgeContractAddress} with total amount ${amount}`,
    ),
  )

  try {
    // Create the LayerZero options with gas limit
    const ESTIMATED_GAS = 300000n

    // Use the proper Options class from LayerZero utilities
    const options = Options.newOptions()
      .addExecutorLzReceiveOption(Number(ESTIMATED_GAS), 0)
      .toBytes()

    const optionsHex = `0x${Buffer.from(options).toString('hex')}` as Hex

    // Properly format the recipient address using LayerZero's utility
    const recipientHex = `0x${Buffer.from(addressToBytes32(recipient)).toString('hex')}` as Hex

    // Send parameter structure matching the contract's expectation
    const sendParam = {
      dstEid: destinationChainEid,
      to: recipientHex,
      amountLD: amount,
      minAmountLD: amount,
      extraOptions: optionsHex,
      composeMsg: '0x' as Hex,
      oftCmd: '0x' as Hex,
    }

    // Get quote for native fee using the complete ABI
    const quoteResult = await publicClient.readContract({
      address: bridgeContractAddress,
      abi: SummerTokenABI.abi,
      functionName: 'quoteSend',
      args: [sendParam, false],
    })

    // Handle different possible return structures
    const estimatedFee =
      typeof quoteResult === 'object' && quoteResult !== null
        ? 'nativeFee' in quoteResult
          ? quoteResult.nativeFee
          : Array.isArray(quoteResult)
            ? quoteResult[0]
            : quoteResult
        : quoteResult
    const safetyBuffer = BigInt(Math.floor(Number(estimatedFee) * safetyMultiplier))

    console.log(
      kleur.blue(
        `- Estimated fee: ${estimatedFee}, with safety buffer: ${safetyBuffer} (${safetyMultiplier}x)`,
      ),
    )

    // Add the bridge transaction
    targets.push(bridgeContractAddress)
    // Include the fee in the transaction value
    values.push(safetyBuffer)
    calldatas.push(
      encodeFunctionData({
        abi: SummerTokenABI.abi, // Use the full ABI from the JSON file
        functionName: 'send',
        args: [
          sendParam,
          {
            nativeFee: safetyBuffer,
            lzTokenFee: 0n,
          },
          refundAddress,
        ],
      }) as Hex,
    )

    console.log(kleur.yellow(`- ETH value for fee: ${safetyBuffer}`))
    console.log(
      kleur.green(
        `- Added bridge transaction for token ${bridgeContractAddress} with amount ${amount}`,
      ),
    )
  } catch (error) {
    console.error(
      kleur.red(
        `- Error preparing bridge transaction for token ${bridgeContractAddress}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      ),
    )
    throw error
  }

  return { targets, values, calldatas }
}

/**
 * Formats a human-readable description for token bridge operations
 *
 * @param tokenSymbols Array of token symbols to bridge
 * @param amounts Array of token amounts to bridge (in same order as symbols)
 * @param sourceChain Name of the source chain
 * @param destinationChain Name of the destination chain
 * @returns The formatted description
 */
export function formatBridgeDescription(
  tokenSymbols: string[],
  amounts: bigint[],
  sourceChain: string,
  destinationChain: string,
): string {
  // Format token amounts for display
  const formattedAmounts = amounts.map((amount, i) => {
    const symbol = tokenSymbols[i]
    return `${amount.toString()} ${symbol}`
  })

  // Create description based on number of tokens
  if (formattedAmounts.length === 1) {
    return `Bridge ${formattedAmounts[0]} from ${sourceChain} to ${destinationChain}`
  } else {
    const amountsList = formattedAmounts.map((amt) => `- ${amt}`).join('\n')
    return `Bridge tokens from ${sourceChain} to ${destinationChain}:\n${amountsList}`
  }
}
