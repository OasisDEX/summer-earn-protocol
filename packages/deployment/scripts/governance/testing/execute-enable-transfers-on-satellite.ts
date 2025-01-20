import { encodeFunctionData, parseAbi, PublicClient } from 'viem'
import { promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { constructLzOptions } from '../../helpers/layerzero-options'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public payable returns (uint256)',
  'function state(uint256 proposalId) public view returns (uint8)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
  'error GovernorNonexistentProposal(uint256)',
])

// Add gas estimation for better cross-chain handling
const GAS_FOR_RELAY = 200000n // 200k gas units
const NATIVE_FEE = 50000000000000000n // 0.05 ETH

async function verifyOAppConfiguration(publicClient: PublicClient, governorAddress: string) {
  console.log('Verifying OApp configuration...')

  const endpointConfig = await publicClient.readContract({
    address: governorAddress,
    abi: parseAbi(['function endpoint() view returns (address)']),
    functionName: 'endpoint',
  })

  console.log('Endpoint configuration:', endpointConfig)
}

async function main() {
  // Get source chain configuration
  const sourceChain = await promptForChain('Which chain is the source of the proposal?')
  const targetChain = await promptForTargetChain(sourceChain.name)

  // Setup clients using wallet helper
  const { publicClient, walletClient } = createClients(sourceChain.chain, sourceChain.rpcUrl)

  const HUB_GOVERNOR_ADDRESS = sourceChain.config.deployedContracts.gov.summerGovernor.address
  const SATELLITE_TOKEN_ADDRESS = targetChain.config.deployedContracts.gov.summerToken.address

  // Update parameters to exactly match the proposal that was created
  const dstTargets = [SATELLITE_TOKEN_ADDRESS]
  const dstValues = [0n]
  const dstCalldatas = [
    encodeFunctionData({
      abi: parseAbi(['function enableTransfers()']),
      args: [],
    }),
  ]
  const dstDescription = `Enable transfers on ${targetChain.name} SummerToken (v3)`

  // Prepare the source-side parameters
  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  // Use helper for LayerZero options
  const lzOptions = constructLzOptions()

  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(targetChain.endpointId),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }),
  ]

  try {
    // Verify the parameters match before execution
    console.log('Verifying proposal parameters match...')
    console.log('Source description hash:', hashDescription(srcDescription))

    const proposalId = await publicClient.readContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
    })

    console.log('Calculated proposal ID:', proposalId)

    // Check the proposal state
    const state = await publicClient.readContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'state',
      args: [proposalId],
    })

    console.log('Proposal ID:', proposalId)
    console.log('Proposal State:', state) // 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed

    if (state !== 5) {
      throw new Error(`Proposal is not in queued state. Current state: ${state}`)
    }

    // Get current gas price for better estimation
    const gasPrice = await publicClient.getGasPrice()
    console.log('Current gas price:', gasPrice)

    // Call this before executing
    await verifyOAppConfiguration(publicClient, HUB_GOVERNOR_ADDRESS)

    console.log('Executing proposal...')
    const hash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'execute',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
      value: 0n,
      gas: GAS_FOR_RELAY,
      maxFeePerGas: gasPrice + (gasPrice * 20n) / 100n, // Add 20% buffer
    })

    console.log('Execution submitted. Transaction hash:', hash)
    console.log('Waiting for transaction receipt...')

    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Execution transaction mined. Block number:', receipt.blockNumber)

    // Add verification steps
    console.log('Verifying transaction status...')
    console.log('Transaction receipt:', receipt)

    if (receipt.status === 'success') {
      console.log(
        'Transaction succeeded! Please check LayerZero scan for cross-chain delivery status',
      )
      console.log(`LayerZero scan URL: https://layerzeroscan.com/tx/${hash}`)
    } else {
      throw new Error('Transaction failed!')
    }
  } catch (error: any) {
    console.error('Error executing proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
    throw error
  }
}

main().catch(console.error)
