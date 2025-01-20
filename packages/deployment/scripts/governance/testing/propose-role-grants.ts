import { encodeFunctionData, keccak256, parseAbi, toBytes } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { createClients } from '../../helpers/wallet-helper'

// Role identifiers
const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))

// TimelockController ABI (only the schedule function)
const timelockAbi = parseAbi([
  'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) public',
])

async function main() {
  // Get chain configuration using the prompt helper
  const chainSetup = await promptForChain('Which chain would you like to grant roles on?')

  // Setup clients using wallet helper
  const { publicClient, walletClient } = createClients(chainSetup.chain, chainSetup.rpcUrl)

  const TIMELOCK_ADDRESS = chainSetup.config.deployedContracts.gov.timelock.address
  const SUMMER_GOVERNOR_ADDRESS = chainSetup.config.deployedContracts.gov.summerGovernor.address

  // Prepare the proposal data
  const calldatas = [
    { role: PROPOSER_ROLE, name: 'PROPOSER_ROLE' },
    { role: CANCELLER_ROLE, name: 'CANCELLER_ROLE' },
    { role: EXECUTOR_ROLE, name: 'EXECUTOR_ROLE' },
  ].map((roleData) =>
    encodeFunctionData({
      abi: parseAbi(['function grantRole(bytes32 role, address account)']),
      args: [roleData.role, SUMMER_GOVERNOR_ADDRESS],
    }),
  )

  const targets = Array(3).fill(TIMELOCK_ADDRESS)
  const values = Array(3).fill(0n)
  const predecessor = '0x0000000000000000000000000000000000000000000000000000000000000000'
  const salt = hashDescription('Grant roles to SummerGovernor')
  const delay = 86400n // 24 hours in seconds

  // Get the current nonce
  const nonce = await publicClient.getTransactionCount({
    address: walletClient.account.address,
  })

  // Get the current gas price and increase it significantly
  const currentGasPrice = await publicClient.getGasPrice()
  const increasedGasPrice = (currentGasPrice * 200n) / 100n // Double the gas price

  console.log(`Using nonce: ${nonce}`)
  console.log(`Current gas price: ${currentGasPrice}`)
  console.log(`Increased gas price: ${increasedGasPrice}`)

  try {
    console.log('Preparing to submit proposals to TimelockController...')

    for (let i = 0; i < targets.length; i++) {
      console.log(`Scheduling proposal ${i + 1}...`)
      console.log('Target:', targets[i])
      console.log('Value:', values[i])
      console.log('Calldata:', calldatas[i])

      const hash = await walletClient.writeContract({
        address: TIMELOCK_ADDRESS,
        abi: timelockAbi,
        functionName: 'schedule',
        args: [targets[i], values[i], calldatas[i], predecessor, salt, delay],
        // nonce: nonce + BigInt(i), // Uncomment if you want to use nonce
        // gasPrice: increasedGasPrice,
      })

      console.log(`Proposal ${i + 1} scheduled. Transaction hash:`, hash)

      // Wait for the transaction to be mined
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      console.log(`Proposal ${i + 1} transaction mined. Block number:`, receipt.blockNumber)
    }
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
    }
  }
}

main().catch(console.error)
