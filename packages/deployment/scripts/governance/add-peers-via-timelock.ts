import dotenv from 'dotenv'
import fs from 'fs'
import inquirer from 'inquirer'
import path from 'path'
import {
  Address,
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  Hex,
  http,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { arbitrum, base, mainnet } from 'viem/chains'

dotenv.config()

// Load configuration from index.json
const configPath = path.resolve(__dirname, '../../config/index.json')
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'))

// Define available chains and their configurations
const chainConfigs = {
  base: {
    chain: base,
    config: config.base,
    rpcUrl: process.env.BASE_RPC_URL as string,
  },
  arbitrum: {
    chain: arbitrum,
    config: config.arbitrum,
    rpcUrl: process.env.ARBITRUM_RPC_URL as string,
  },
  mainnet: {
    chain: mainnet,
    config: config.mainnet,
    rpcUrl: process.env.MAINNET_RPC_URL as string,
  },
}

async function promptForChain(): Promise<{
  name: string
  config: any
  chain: any
  rpcUrl: string
}> {
  const chainOptions = Object.keys(chainConfigs).map((key) => ({
    name: key,
    value: { name: key, ...chainConfigs[key as keyof typeof chainConfigs] },
  }))

  const { selectedChain } = await inquirer.prompt([
    {
      type: 'list',
      name: 'selectedChain',
      message: 'Which chain would you like to execute this operation on?',
      choices: chainOptions,
    },
  ])

  // Confirm chain selection
  const { confirmChain } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmChain',
      message: `Please confirm you want to execute on ${selectedChain.name}`,
      default: false,
    },
  ])

  if (!confirmChain) {
    throw new Error('Operation cancelled by user')
  }

  return selectedChain
}

// Add interface for peer chain selection
interface PeerChainOption {
  name: string
  config: any
  endpointId: string
}

async function promptForPeerChain(currentChain: string): Promise<PeerChainOption> {
  // Filter out the current chain from options
  const peerChainOptions = Object.entries(chainConfigs)
    .filter(([key]) => key !== currentChain)
    .map(([key, value]) => ({
      name: key,
      value: {
        name: key,
        config: value.config,
        endpointId: value.config.common.layerZero.eID,
      },
    }))

  const { selectedPeerChain } = await inquirer.prompt([
    {
      type: 'list',
      name: 'selectedPeerChain',
      message: 'Which chain would you like to add as a peer?',
      choices: peerChainOptions,
    },
  ])

  // Confirm peer chain selection
  const { confirmPeerChain } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmPeerChain',
      message: `Please confirm you want to add ${selectedPeerChain.name} as a peer`,
      default: false,
    },
  ])

  if (!confirmPeerChain) {
    throw new Error('Operation cancelled by user')
  }

  return selectedPeerChain
}

async function main() {
  console.log('🚀 Starting peer addition process...\n')

  // Get and confirm chain selection
  const { config: chainConfig, chain, rpcUrl, name } = await promptForChain()

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  const account = privateKeyToAccount(`0x${process.env.PRIVATE_KEY as Hex}`)
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  // Reduce gas parameters
  const GAS_LIMIT = 500000n
  const MAX_FEE_PER_GAS = 1500000000n // 1.5 gwei (reduced from 150 gwei)
  const MAX_PRIORITY_FEE_PER_GAS = 1500000000n // 1.5 gwei (reduced from 15 gwei)

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
    const contractOptions: ContractOption[] = [
      {
        name: 'Summer Token',
        address: chainConfig.deployedContracts.gov.summerToken.address as Address,
      },
      {
        name: 'Governor',
        address: chainConfig.deployedContracts.gov.summerGovernor.address as Address,
      },
    ]

    const { selectedContract } = await inquirer.prompt([
      {
        type: 'list',
        name: 'selectedContract',
        message: 'Which contract would you like to add peers to?',
        choices: contractOptions.map((contract) => ({
          name: `${contract.name} (${contract.address})`,
          value: contract,
        })),
      },
    ])

    // Confirm contract selection
    const { confirmContract } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirmContract',
        message: `Please confirm you want to add a peer to ${selectedContract.name} at ${selectedContract.address}`,
        default: false,
      },
    ])

    if (!confirmContract) {
      throw new Error('Operation cancelled by user')
    }

    return selectedContract
  }

  // Get and confirm contract selection
  const selectedContract = await promptForContract()

  // Get and confirm peer chain selection
  const peerChain = await promptForPeerChain(name)
  console.log('peerChain', peerChain)

  // Define peer address based on contract selection
  const PEER_CONTRACT_ADDRESS =
    selectedContract.name === 'Summer Token'
      ? (peerChain.config.deployedContracts.gov.summerToken.address as Address)
      : (peerChain.config.deployedContracts.gov.summerGovernor.address as Address)
  const PEER_ENDPOINT_ID = peerChain.config.common.layerZero.eID as string

  const TIMELOCK_ADDRESS = chainConfig.deployedContracts.gov.timelock.address as Address

  // Show final confirmation with all details
  const { confirmOperation } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmOperation',
      message:
        `📝 Please review the operation details:\n\n` +
        `Chain: ${name}\n` +
        `Target Contract: ${selectedContract.name} (${selectedContract.address})\n` +
        `Peer Chain: ${peerChain.name}\n` +
        `Peer Address: ${PEER_CONTRACT_ADDRESS}\n` +
        `Endpoint ID: ${PEER_ENDPOINT_ID}\n` +
        `Timelock: ${TIMELOCK_ADDRESS}\n\n` +
        `Would you like to proceed with scheduling this operation?`,
      default: false,
    },
  ])

  if (!confirmOperation) {
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
  const { confirmExecution } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmExecution',
      message: `\nWould you like to wait ${delay} seconds and execute the operation?`,
      default: false,
    },
  ])

  if (!confirmExecution) {
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
