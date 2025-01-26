import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import { promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { createClients } from '../../helpers/wallet-helper'

async function main() {
  console.log('🚀 Starting peer addition process...\n')

  // Get hub chain configuration through prompt
  const {
    config: chainConfig,
    name: hubChainName,
    chain,
    rpcUrl,
  } = await promptForChain('Select the hub chain:')

  const { publicClient, walletClient } = await createClients(chain, rpcUrl)

  // Reduce gas parameters
  const GAS_LIMIT = 500000n
  const MAX_FEE_PER_GAS = 1500000000n // 1.5 gwei
  const MAX_PRIORITY_FEE_PER_GAS = 1500000000n // 1.5 gwei

  function createSetPeerCalldata(
    peerAddress: Address,
    endpointId: string,
    targetContract: Address,
  ): Hex {
    const peerAddressAsBytes32 = `0x000000000000000000000000${peerAddress.slice(2)}` as Hex

    return encodeFunctionData({
      abi: [
        {
          name: 'setPeer',
          type: 'function',
          inputs: [
            { name: '_eid', type: 'uint32' },
            { name: '_peer', type: 'bytes32' },
          ],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ],
      args: [Number(endpointId), peerAddressAsBytes32],
    })
  }

  async function scheduleSetPeerOperation(
    publicClient: any,
    walletClient: any,
    delay: bigint,
    targetContract: Address,
  ) {
    const setPeerCalldata = createSetPeerCalldata(
      PEER_CONTRACT_ADDRESS,
      PEER_ENDPOINT_ID,
      targetContract,
    )

    const hasRole = await publicClient.readContract({
      address: TIMELOCK_ADDRESS,
      abi: [
        {
          name: 'hasRole',
          type: 'function',
          inputs: [
            { name: 'role', type: 'bytes32' },
            { name: 'account', type: 'address' },
          ],
          outputs: [{ type: 'bool' }],
          stateMutability: 'view',
        },
      ],
      functionName: 'hasRole',
      args: [
        '0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1', // PROPOSER_ROLE
        walletClient.account.address,
      ],
    })
    console.log('Has proposer role:', hasRole)

    if (!hasRole) {
      throw new Error('User does not have PROPOSER_ROLE')
    }

    const scheduleTx = encodeFunctionData({
      abi: [
        {
          name: 'schedule',
          type: 'function',
          inputs: [
            { name: 'target', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'data', type: 'bytes' },
            { name: 'predecessor', type: 'bytes32' },
            { name: 'salt', type: 'bytes32' },
            { name: 'delay', type: 'uint256' },
          ],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ],
      args: [
        targetContract, // Use the target contract address
        0n,
        setPeerCalldata,
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        delay,
      ],
    })

    const tx = await walletClient.sendTransaction({
      to: TIMELOCK_ADDRESS,
      data: scheduleTx,
      value: 0n,
      gas: GAS_LIMIT, // Use increased gas limit
      maxFeePerGas: MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
    })

    console.log(`Schedule transaction sent: ${tx}`)

    // Add transaction receipt logging
    const receipt = await publicClient.waitForTransactionReceipt({ hash: tx })
    console.log('Transaction mined:', {
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed,
      effectiveGasPrice: receipt.effectiveGasPrice,
    })
  }

  async function executeSetPeerOperation(walletClient: any, targetContract: Address) {
    const setPeerCalldata = createSetPeerCalldata(
      PEER_CONTRACT_ADDRESS,
      PEER_ENDPOINT_ID,
      targetContract,
    )

    const executeTx = encodeFunctionData({
      abi: [
        {
          name: 'execute',
          type: 'function',
          inputs: [
            { name: 'target', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'data', type: 'bytes' },
            { name: 'predecessor', type: 'bytes32' },
            { name: 'salt', type: 'bytes32' },
          ],
          outputs: [],
          stateMutability: 'payable',
        },
      ],
      args: [
        targetContract, // Use the target contract address
        0n,
        setPeerCalldata,
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000000000000000000000000000',
      ],
    })

    const tx = await walletClient.sendTransaction({
      to: TIMELOCK_ADDRESS,
      data: executeTx,
      value: 0n,
      gas: GAS_LIMIT, // Use increased gas limit
      maxFeePerGas: MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
    })

    console.log(`Execute transaction sent: ${tx}`)
  }

  // Add interface for contract options
  interface ContractOption {
    name: string
    address: Address
  }

  async function promptForContract(): Promise<ContractOption> {
    const contractOptions = [
      {
        title: 'Summer Token',
        value: {
          name: 'Summer Token',
          address: chainConfig.deployedContracts.gov.summerToken.address as Address,
        },
      },
      {
        title: 'Governor',
        value: {
          name: 'Governor',
          address: chainConfig.deployedContracts.gov.summerGovernor.address as Address,
        },
      },
    ]

    const { selectedContract } = await prompts({
      type: 'select',
      name: 'selectedContract',
      message: 'Which contract would you like to add peers to?',
      choices: contractOptions.map((contract) => ({
        title: `${contract.title} (${contract.value.address})`,
        value: contract.value,
      })),
    })

    if (!selectedContract) throw new Error('No contract selected')

    const { confirmed } = await prompts({
      type: 'confirm',
      name: 'confirmed',
      message: `Please confirm you want to add a peer to ${selectedContract.name} at ${selectedContract.address}`,
      initial: false,
    })

    if (!confirmed) {
      throw new Error('Operation cancelled by user')
    }

    return selectedContract
  }

  // Get and confirm contract selection
  const selectedContract = await promptForContract()

  // Get and confirm target chain selection (replacing peer chain)
  const targetChain = await promptForTargetChain(hubChainName)
  console.log('targetChain', targetChain)

  // Define peer address based on contract selection
  const PEER_CONTRACT_ADDRESS =
    selectedContract.name === 'Summer Token'
      ? (targetChain.config.deployedContracts.gov.summerToken.address as Address)
      : (targetChain.config.deployedContracts.gov.summerGovernor.address as Address)
  const PEER_ENDPOINT_ID = targetChain.endpointId

  const TIMELOCK_ADDRESS = chainConfig.deployedContracts.gov.timelock.address as Address

  // Show final confirmation with all details
  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message:
      `📝 Please review the operation details:\n\n` +
      `Hub Chain: ${hubChainName}\n` +
      `Target Contract: ${selectedContract.name} (${selectedContract.address})\n` +
      `Target Chain: ${targetChain.name}\n` +
      `Peer Address: ${PEER_CONTRACT_ADDRESS}\n` +
      `Endpoint ID: ${PEER_ENDPOINT_ID}\n` +
      `Timelock: ${TIMELOCK_ADDRESS}\n\n` +
      `Would you like to proceed with scheduling this operation?`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  console.log('\n🔄 Fetching timelock delay...')
  const delay = (await publicClient.readContract({
    address: TIMELOCK_ADDRESS,
    abi: [
      {
        name: 'getMinDelay',
        type: 'function',
        inputs: [],
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
      },
    ],
    functionName: 'getMinDelay',
  })) as bigint

  console.log(`⏰ Timelock delay: ${delay} seconds\n`)

  // Schedule operation
  console.log('📋 Scheduling operation...')
  // await scheduleSetPeerOperation(publicClient, walletClient, delay, selectedContract.address)

  // Confirm execution
  const { executeNow } = await prompts({
    type: 'confirm',
    name: 'executeNow',
    message: `\nWould you like to wait ${delay} seconds and execute the operation?`,
    initial: false,
  })

  if (!executeNow) {
    console.log('❌ Operation scheduled but execution cancelled by user')
    return
  }

  console.log('\n⏳ Waiting for timelock delay...')
  // await new Promise((resolve) => setTimeout(resolve, Number(delay + 10n) * 1000))

  console.log('🚀 Executing timelock operation...')
  await executeSetPeerOperation(walletClient, selectedContract.address)

  console.log('✅ Operation completed successfully!')
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
