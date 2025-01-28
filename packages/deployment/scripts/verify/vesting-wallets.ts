import dotenv from 'dotenv'
import hre from 'hardhat'
import prompts from 'prompts'

import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { resolve } from 'path'
import { createPublicClient, decodeEventLog, http } from 'viem'
import { ChainName, chainConfigs } from '../helpers/chain-configs'
import { getConfigByNetwork } from '../helpers/config-handler'

dotenv.config()

const multiSources = [resolve(__dirname, '../../../gov-contracts/src')]

export async function verifyVestingWallets(hre: HardhatRuntimeEnvironment) {
  for (const sourcePath of multiSources || []) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }
  const config = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: false,
  })
  const chainConfig = chainConfigs[hre.network.name as ChainName]

  const publicClient = createPublicClient({
    chain: chainConfig.chain,
    transport: http(chainConfig.rpcUrl),
  })

  // Get beneficiary address from user
  const { beneficiaryAddress } = await prompts({
    type: 'text',
    name: 'beneficiaryAddress',
    message: 'Enter the beneficiary address:',
    validate: (value) =>
      /^0x[a-fA-F0-9]{40}$/.test(value) ? true : 'Please enter a valid Ethereum address',
  })

  // Get vesting wallet factory and wallet address
  const vestingWalletFactory = await publicClient.readContract({
    address: config.deployedContracts.gov.summerToken.address as `0x${string}`,
    abi: [
      {
        inputs: [],
        name: 'vestingWalletFactory',
        outputs: [{ type: 'address' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'vestingWalletFactory',
  })

  const vestingWalletsAddress = await publicClient.readContract({
    address: vestingWalletFactory,
    abi: [
      {
        inputs: [{ type: 'address' }],
        name: 'vestingWallets',
        outputs: [{ type: 'address' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'vestingWallets',
    args: [beneficiaryAddress],
  })

  // Get creation logs to extract parameters
  const vestingWalletCreatedEvent = {
    inputs: [
      { type: 'address', name: 'beneficiary', indexed: true },
      { type: 'address', name: 'wallet', indexed: true },
      { type: 'uint256', name: 'timeBasedAmount' },
      { type: 'uint256[]', name: 'goalAmounts' },
      { type: 'uint8', name: 'vestingType' },
    ],
    name: 'VestingWalletCreated',
    type: 'event',
  } as const

  const logs = await publicClient.getLogs({
    address: vestingWalletFactory,
    event: vestingWalletCreatedEvent,
    fromBlock: 'earliest',
    toBlock: 'latest',
  })

  const relevantLog = logs.find((log) => {
    const decoded = decodeEventLog({
      abi: [vestingWalletCreatedEvent],
      data: log.data,
      topics: log.topics,
    })
    return (
      decoded.args.wallet?.toLowerCase() === vestingWalletsAddress.toLowerCase() &&
      decoded.args.beneficiary?.toLowerCase() === beneficiaryAddress.toLowerCase()
    )
  })

  if (!relevantLog) {
    throw new Error('Could not find creation logs for this vesting wallet')
  }

  const { timeBasedAmount, goalAmounts, vestingType } = relevantLog.args

  // Use block timestamp as startTimestamp since it's not in the event
  const startTimestamp = BigInt(
    await publicClient
      .getBlock({
        blockNumber: relevantLog.blockNumber,
      })
      .then((block) => block.timestamp),
  )

  console.log('Found parameters from logs:', {
    startTimestamp,
    vestingType,
    timeBasedAmount,
    goalAmounts,
  })

  try {
    await hre.run('verify:verify', {
      address: vestingWalletsAddress,
      contract: 'src/contracts/SummerVestingWallet.sol:SummerVestingWallet',
      constructorArguments: [
        config.deployedContracts.gov.summerToken.address,
        beneficiaryAddress,
        startTimestamp,
        vestingType,
        timeBasedAmount,
        goalAmounts,
        config.deployedContracts.gov.protocolAccessManager.address,
      ],
    })
  } catch (error) {
    console.error('Error verifying contract:', error)
  }
}

if (require.main === module) {
  verifyVestingWallets(hre).catch(console.error)
}
