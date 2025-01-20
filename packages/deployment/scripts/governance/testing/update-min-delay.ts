import { encodeFunctionData, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { createClients } from '../../helpers/wallet-helper'

// SummerGovernor ABI (only the propose function)
const governorAbi = parseAbi([
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
])

async function main() {
  // Get chain configuration and setup clients
  const chainSetup = await promptForChain()
  const { publicClient, walletClient } = createClients(chainSetup.chain, chainSetup.rpcUrl)

  // Get contract addresses from chain config
  const TIMELOCK_ADDRESS = chainSetup.config.deployedContracts.gov.timelock.address
  const SUMMER_GOVERNOR_ADDRESS = chainSetup.config.deployedContracts.gov.summerGovernor.address

  // Prepare the proposal data
  const newMinDelay = 3600n // 1 hour in seconds
  const calldatas = [
    encodeFunctionData({
      abi: parseAbi(['function updateDelay(uint256 newDelay)']),
      args: [newMinDelay],
    }),
  ]

  const targets = [TIMELOCK_ADDRESS]
  const values = [0n]
  const description = `Update TimelockController minimum delay to ${newMinDelay} seconds (1 hour)`

  try {
    console.log('Preparing to submit proposal...')
    console.log('Target:', targets[0])
    console.log('Value:', values[0])
    console.log('Calldata:', calldatas[0])
    console.log('Description:', description)

    const hash = await walletClient.writeContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
    })

    console.log('Proposal submitted. Transaction hash:', hash)
    console.log('Proposal description hash:', hashDescription(description))

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Transaction mined. Block number:', receipt.blockNumber)
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
