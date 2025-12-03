import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, parseAbi, toBytes, keccak256 } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * @dev Creates a Safe transaction proposal to schedule an ERC20 approval in the SummerTimelockController
 *
 * Token address: 0x2433D6AC11193b4695D9ca73530de93c538aD18a
 * Spender address: Set via SPENDER_ADDRESS environment variable (or use placeholder)
 * Approval amount: Set via APPROVAL_AMOUNT environment variable (or use max uint256)
 */
export async function scheduleTokenApprovalSafe(useBummerConfig = false) {
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

  const tokenAddress = validateAddress(
    '0x2433D6AC11193b4695D9ca73530de93c538aD18a',
    'vault_receipt_token',
  )

  const spenderAddress = validateAddress('0x77e5f42d5cf2d1B9849AE6A5d2D7dC5b774f8290', 'executor')

  const approvalAmount = BigInt(
    '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
  )

  // Read minDelay from timelock contract
  const timelock = await hre.viem.getContractAt('SummerTimelockController', timelockAddress)
  const minDelay = await timelock.read.getMinDelay()
  console.log(kleur.blue('Timelock minDelay:'), kleur.cyan(`${minDelay.toString()} seconds`))

  const transactions = []

  // Encode the ERC20 approve function call
  const erc20ApproveAbi = parseAbi([
    'function approve(address spender, uint256 amount) external returns (bool)',
  ])
  const approveCalldata = encodeFunctionData({
    abi: erc20ApproveAbi,
    functionName: 'approve',
    args: [spenderAddress, approvalAmount],
  })

  // Generate salt (using timestamp for uniqueness)
  const salt = keccak256(toBytes(Date.now().toString()))

  // Encode the timelock schedule function call
  const timelockScheduleAbi = parseAbi([
    'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) external',
  ])

  const scheduleCalldata = encodeFunctionData({
    abi: timelockScheduleAbi,
    functionName: 'schedule',
    args: [
      tokenAddress, // target: token address
      0n, // value: 0 (ERC20 approval doesn't need ETH)
      approveCalldata, // data: encoded approve() call
      '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`, // predecessor: no predecessor
      salt, // salt: unique identifier
      minDelay, // delay: minimum delay from timelock
    ],
  })

  transactions.push({
    to: timelockAddress,
    value: '0',
    data: scheduleCalldata,
    contractMethod: {
      inputs: [
        { name: 'target', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'data', type: 'bytes' },
        { name: 'predecessor', type: 'bytes32' },
        { name: 'salt', type: 'bytes32' },
        { name: 'delay', type: 'uint256' },
      ],
      name: 'schedule',
      payable: false,
    },
    contractInputsValues: {
      target: tokenAddress,
      value: '0',
      data: approveCalldata,
      predecessor: '0x0000000000000000000000000000000000000000000000000000000000000000',
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
      name: 'Schedule ERC20 Approval in Timelock',
      description: `Schedule approval of ${approvalAmount.toString()} tokens for ${spenderAddress} on token ${tokenAddress}`,
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

  const fileName = `schedule_token_approval_safe_tx_${timestamp}.json`
  const outputPath = path.join(govV2SetupDir, fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
  console.log(
    kleur.cyan(
      `\nNote: This will schedule the approval. After the delay (${minDelay.toString()} seconds), the approval can be executed.`,
    ),
  )
}

if (require.main === module) {
  scheduleTokenApprovalSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
