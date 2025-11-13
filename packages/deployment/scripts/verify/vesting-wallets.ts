import dotenv from 'dotenv'
import hre from 'hardhat'
import prompts from 'prompts'

import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { resolve } from 'path'
import { createPublicClient, decodeEventLog, http } from 'viem'
import { ChainName, getChainConfigs } from '../helpers/chain-configs'
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
  }) as any
  const chainConfigs = getChainConfigs()
  let networkName: ChainName

  // Map hardhat/local to base for chain configs (same as config handler does)
  if (hre.network.name === 'hardhat' || hre.network.name === 'local') {
    networkName = 'base'
  } else {
    networkName = hre.network.name as ChainName
  }

  const chainConfig = chainConfigs[networkName]
  if (!chainConfig) {
    throw new Error(
      `Chain config not found for network: ${networkName}. Available networks: ${Object.keys(chainConfigs).join(', ')}`,
    )
  }

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

  // Get vesting wallet factory V2 address from deployment config
  // Note: SummerToken contract doesn't have vestingWalletFactoryV2 function,
  // so we need to get the deployed address from the config
  const vestingWalletFactory = config.deployedContracts.gov.summerVestingFactoryV2
    .address as `0x${string}`

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

  // Get creation logs to extract parameters for V2
  const vestingWalletCreatedEvent = {
    inputs: [
      { type: 'address', name: 'beneficiary', indexed: true },
      { type: 'address', name: 'vestingWallet', indexed: true },
      {
        type: 'tuple',
        name: 'vestingParams',
        components: [
          { type: 'uint64', name: 'cliffEndTimestamp' },
          { type: 'uint256', name: 'cliffAmount' },
          { type: 'uint256', name: 'vestingPeriods' },
          { type: 'uint256', name: 'totalVestingAmount' },
        ],
      },
      { type: 'uint256', name: 'performanceGoalsCount' },
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
      decoded.args.vestingWallet?.toLowerCase() === vestingWalletsAddress.toLowerCase() &&
      decoded.args.beneficiary?.toLowerCase() === beneficiaryAddress.toLowerCase()
    )
  })

  if (!relevantLog) {
    throw new Error('Could not find creation logs for this vesting wallet')
  }

  const { vestingParams, performanceGoalsCount } = relevantLog.args

  // Get performance goals from the vesting wallet contract
  const performanceGoals = []
  for (let i = 1; i <= (performanceGoalsCount || 0); i++) {
    const goal = await publicClient.readContract({
      address: vestingWalletsAddress,
      abi: [
        {
          inputs: [{ type: 'uint256' }],
          name: 'performanceGoals',
          outputs: [
            {
              type: 'tuple',
              components: [
                { type: 'uint256', name: 'amount' },
                { type: 'string', name: 'description' },
                { type: 'bool', name: 'reached' },
              ],
            },
          ],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      functionName: 'performanceGoals',
      args: [BigInt(i)],
    })
    performanceGoals.push(goal)
  }

  console.log('Found parameters from logs:', {
    vestingParams,
    performanceGoals,
  })

  try {
    await hre.run('verify:verify', {
      address: vestingWalletsAddress,
      contract: 'src/contracts/SummerVestingWalletV2.sol:SummerVestingWalletV2',
      constructorArguments: [
        config.deployedContracts.gov.summerToken.address,
        beneficiaryAddress,
        vestingParams,
        performanceGoals,
        vestingWalletFactory,
      ],
    })
  } catch (error) {
    console.error('Error verifying contract:', error)
  }
}

if (require.main === module) {
  verifyVestingWallets(hre).catch(console.error)
}
