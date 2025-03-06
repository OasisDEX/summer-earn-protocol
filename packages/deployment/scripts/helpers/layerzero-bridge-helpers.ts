import { addressToBytes32, Options } from '@layerzerolabs/lz-v2-utilities'
import hre from 'hardhat'
import kleur from 'kleur'
import { Address, encodeFunctionData, Hex } from 'viem'

const OFT_ABI = [
  {
    name: 'quoteSend',
    inputs: [
      {
        name: 'sendParam',
        type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
      },
      { name: 'payInLzToken', type: 'bool' },
    ],
    outputs: [
      { name: 'nativeFee', type: 'uint256' },
      { name: 'lzTokenFee', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    name: 'send',
    inputs: [
      {
        name: 'sendParam',
        type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
      },
      {
        name: 'fee',
        type: 'tuple',
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ],
      },
      { name: 'refundAddress', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

/**
 * Prepares actions for bridging tokens across chains using LayerZero
 * Aggregates amounts for each token to minimize the number of cross-chain transactions
 * Includes fee estimation with safety buffer for governance timelock delays
 *
 * @param bridgeContractAddress The address of the bridge contract (OFT)
 * @param amount The amount to bridge
 * @param destinationChainEid The LayerZero endpoint ID of the destination chain
 * @param recipient Recipient address on the destination chain (defaults to executing address)
 * @param refundAddress Optional refund address for excess fees (defaults to executing address)
 * @param safetyMultiplier The safety multiplier for the bridge transaction
 * @returns Object containing targets, values, and calldatas for governance proposal
 */
export async function prepareBridgeTransaction(
  bridgeContractAddress: Address,
  amount: bigint,
  destinationChainEid: number,
  recipient: Address,
  refundAddress: Address,
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
    // Create the LayerZero options
    const ESTIMATED_GAS = 300000n

    // Use the proper Options class from LayerZero utilities
    const options = Options.newOptions()
      .addExecutorLzReceiveOption(Number(ESTIMATED_GAS), 0)
      .toBytes()

    const optionsHex = `0x${Buffer.from(options).toString('hex')}` as Hex

    // Properly format the recipient address using LayerZero's utility
    const recipientHex = `0x${Buffer.from(addressToBytes32(recipient)).toString('hex')}` as Hex

    // Get the bridge contract
    const publicClient = await hre.viem.getPublicClient()

    const sendParam = {
      dstEid: destinationChainEid,
      to: recipientHex,
      amountLD: amount,
      minAmountLD: amount,
      extraOptions: optionsHex,
      composeMsg: '0x' as Hex,
      oftCmd: '0x' as Hex,
    }

    // Get quote for native fee
    const quoteResult = await publicClient.readContract({
      address: bridgeContractAddress,
      abi: OFT_ABI,
      functionName: 'quoteSend',
      args: [sendParam, false],
    })

    // Apply safety multiplier to native fee
    const estimatedFee = quoteResult[0]
    const safetyBuffer = BigInt(Math.floor(Number(estimatedFee) * safetyMultiplier))

    console.log(
      kleur.blue(
        `- Estimated fee: ${estimatedFee}, with safety buffer: ${safetyBuffer} (${safetyMultiplier}x)`,
      ),
    )
    // Add the bridge transaction
    targets.push(bridgeContractAddress)
    values.push(0n) // Ensure there is already ETH balance on timelock
    calldatas.push(
      encodeFunctionData({
        abi: OFT_ABI,
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

    console.log(kleur.yellow(`- Ensure there is already ETH balance on timelock`))

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
