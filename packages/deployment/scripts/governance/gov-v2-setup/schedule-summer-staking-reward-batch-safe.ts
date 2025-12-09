import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { encodeFunctionData, parseAbi, toBytes, keccak256 } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * @dev Creates a Safe transaction proposal to schedule, via the SummerTimelockController,
 *      a batch of two operations:
 *      1) Approve the SummerStaking contract to pull 5,000 SUMMER tokens from the timelock
 *      2) Notify a 24h reward period of 5,000 SUMMER tokens in SummerStaking
 *
 * Token address: from config.deployedContracts.gov.summerToken.address
 * Staking contract: from config.deployedContracts.govV2.summerStaking.address
 *
 * Amount: 5,000 * 1e18 SUMMER
 * Rewards duration: 24 hours (86400 seconds)
 */
export async function scheduleSummerStakingRewardBatchSafe(useBummerConfig = false) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  const publicClient = await hre.viem.getPublicClient()
  const foundationMultisig = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisig) {
    throw new Error('FOUNDATION_MULTISIG_ADDRESS environment variable is not set')
  }
  const multisigAddress = validateAddress(foundationMultisig, 'FOUNDATION_MULTISIG_ADDRESS')

  const timelockAddress = validateAddress(
    config.deployedContracts.govV2.timelock.address,
    'govV2.timelock',
  )

  const summerTokenAddress = validateAddress(
    config.deployedContracts.gov.summerToken.address,
    'gov.summerToken',
  )

  const summerStakingAddress = validateAddress(
    config.deployedContracts.govV2.summerStaking.address,
    'govV2.summerStaking',
  )

  // Read minDelay from timelock contract
  const timelock = await hre.viem.getContractAt('SummerTimelockController', timelockAddress)
  const minDelay = await timelock.read.getMinDelay()
  console.log(kleur.blue('Timelock minDelay:'), kleur.cyan(`${minDelay.toString()} seconds`))

  // Constants: 450,000 SUMMER over 90 days
  const REWARD_AMOUNT = 450000n * 10n ** 18n // 450,000 * 1e18
  const REWARD_DURATION = 90n * 24n * 60n * 60n // 90 days in seconds

  console.log(
    kleur.blue('Reward amount (wei):'),
    kleur.cyan(REWARD_AMOUNT.toString()),
    kleur.blue('Reward duration (seconds):'),
    kleur.cyan(REWARD_DURATION.toString()),
  )

  const transactions: any[] = []

  // Encode the ERC20 approve function call: approve(SummerStaking, 450,000 SUMMER)
  const erc20ApproveAbi = parseAbi([
    'function approve(address spender, uint256 amount) external returns (bool)',
  ])

  const approveCalldata = encodeFunctionData({
    abi: erc20ApproveAbi,
    functionName: 'approve',
    args: [summerStakingAddress, REWARD_AMOUNT],
  })

  // Encode the SummerStaking.notifyRewardAmount call
  const notifyRewardAmountAbi = parseAbi([
    'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
  ])

  const notifyCalldata = encodeFunctionData({
    abi: notifyRewardAmountAbi,
    functionName: 'notifyRewardAmount',
    args: [summerTokenAddress, REWARD_AMOUNT, REWARD_DURATION],
  })

  // Generate salt (using timestamp for uniqueness)
  const salt = keccak256(toBytes(Date.now().toString()))
  const ZERO_BYTES32 =
    '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`

  // Encode the timelock scheduleBatch function call
  const timelockScheduleBatchAbi = parseAbi([
    'function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) external',
  ])

  const scheduleBatchCalldata = encodeFunctionData({
    abi: timelockScheduleBatchAbi,
    functionName: 'scheduleBatch',
    args: [
      [summerTokenAddress, summerStakingAddress],
      [0n, 0n],
      [approveCalldata, notifyCalldata],
      ZERO_BYTES32,
      salt,
      minDelay,
    ],
  })

  transactions.push({
    to: timelockAddress,
    value: '0',
    data: scheduleBatchCalldata,
    contractMethod: {
      inputs: [
        { name: 'targets', type: 'address[]' },
        { name: 'values', type: 'uint256[]' },
        { name: 'payloads', type: 'bytes[]' },
        { name: 'predecessor', type: 'bytes32' },
        { name: 'salt', type: 'bytes32' },
        { name: 'delay', type: 'uint256' },
      ],
      name: 'scheduleBatch',
      payable: false,
    },
    contractInputsValues: {
      targets: [summerTokenAddress, summerStakingAddress],
      values: ['0', '0'],
      payloads: [approveCalldata, notifyCalldata],
      predecessor: ZERO_BYTES32,
      salt: salt,
      delay: minDelay.toString(),
    },
  })

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Schedule 5,000 SUMMER rewards for 24h in SummerStaking (batch)',
      description: `Schedule a timelock batch that (1) approves ${REWARD_AMOUNT.toString()} SUMMER for SummerStaking and (2) notifies rewards for 24h in SummerStaking`,
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions,
  }

  // Ensure proposals directory exists
  const proposalsDir = path.join(process.cwd(), 'proposals')
  const govV2SetupDir = path.join(proposalsDir, 'gov-v2-setup')
  if (!fs.existsSync(govV2SetupDir)) {
    fs.mkdirSync(govV2SetupDir, { recursive: true })
  }

  const fileName = `schedule_summer_staking_reward_batch_safe_tx_${timestamp}.json`
  const outputPath = path.join(govV2SetupDir, fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
  console.log(
    kleur.cyan(
      `\nNote: This will schedule a batch to approve and notify 450,000 SUMMER rewards for 90 days. After the delay (${minDelay.toString()} seconds), the batch can be executed by the timelock.`,
    ),
  )
}

if (require.main === module) {
  scheduleSummerStakingRewardBatchSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
