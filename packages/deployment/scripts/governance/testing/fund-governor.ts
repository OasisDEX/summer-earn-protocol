import prompts from 'prompts'
import { Address, formatEther, parseAbi, parseEther } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

async function main() {
  // Get chain configuration through prompt
  const { config, chain, name: chainName, rpcUrl } = await promptForChain('Select the chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Extract addresses from config
  const TIMELOCK_ADDRESS = config.deployedContracts.gov.timelock.address as Address
  const SUMMER_GOVERNOR_ADDRESS = config.deployedContracts.gov.summerGovernor.address as Address

  // Get timelock balance
  const timelockBalance = await publicClient.getBalance({ address: TIMELOCK_ADDRESS })
  console.log(`\nCurrent timelock balance on ${chainName}: ${formatEther(timelockBalance)} ETH`)

  // Prompt for amount to transfer
  const { amount } = await prompts({
    type: 'text',
    name: 'amount',
    message: 'Enter amount of ETH to transfer:',
    validate: (value) => !isNaN(Number(value)) || 'Please enter a valid number',
  })

  const transferAmount = parseEther(amount)

  if (timelockBalance < transferAmount) {
    throw new Error(
      `Timelock balance (${formatEther(timelockBalance)} ETH) is less than transfer amount (${amount} ETH)`,
    )
  }

  // Confirm the transaction
  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Are you sure you want to create a proposal to transfer ${amount} ETH to the Governor?`,
    initial: false,
  })

  if (!confirmed) {
    console.log('Operation cancelled')
    return
  }

  try {
    console.log('\nPreparing to submit proposal...')

    const targets = [SUMMER_GOVERNOR_ADDRESS]
    const values = [transferAmount]
    const calldatas: `0x${string}`[] = ['0x']
    const description = `Transfer ${amount} ETH to Governor for cross-chain messaging fees (#2)`

    //Transfer 0.005 ETH to Governor for cross-chain messaging fees (#2)
    console.log('Target:', targets[0])
    console.log('Transfer amount:', amount, 'ETH')
    console.log('Description:', description)

    // Get current gas price and add 20% buffer
    const currentGasPrice = await publicClient.getGasPrice()
    const adjustedGasPrice = (currentGasPrice * 120n) / 100n

    // Simulate the transaction first
    console.log('\nSimulating transaction...')
    await publicClient.simulateContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
      account: walletClient.account.address,
    })

    // Submit the proposal
    console.log('Simulation successful, submitting transaction...')
    const hash = await walletClient.writeContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
      gas: 5_000_000n, // 5M
      maxFeePerGas: adjustedGasPrice,
    })

    console.log('\nProposal submitted. Transaction hash:', hash)
    console.log('Waiting for transaction confirmation...')

    // Wait for the transaction to be mined with more detailed status
    const receipt = await publicClient.waitForTransactionReceipt({
      hash,
      timeout: 60_000, // 60 second timeout
      confirmations: 1,
    })

    if (receipt.status === 'reverted') {
      throw new Error('Transaction reverted on chain')
    }

    console.log('Transaction successfully mined in block:', receipt.blockNumber)
    console.log('Transaction status:', receipt.status === 'success' ? 'SUCCESS ✅' : 'FAILED ❌')
    console.log('Gas used:', receipt.gasUsed.toString())

    // Calculate and display the proposal ID for reference
    const proposalId = await publicClient.readContract({
      address: SUMMER_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [targets, values, calldatas, hashDescription(description)],
    })

    console.log('\nProposal ID:', proposalId)
    console.log('\nNext steps:')
    console.log('1. Vote on the proposal')
    console.log('2. Queue the proposal')
    console.log('3. Execute the proposal after timelock delay')
  } catch (error: any) {
    console.error('\n❌ Transaction failed!')
    console.error('Error details:', error.message)
    if (error.cause) {
      console.error('Error cause:', error.cause.message || error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
    process.exit(1) // Exit with error code
  }
}

main().catch(console.error)
