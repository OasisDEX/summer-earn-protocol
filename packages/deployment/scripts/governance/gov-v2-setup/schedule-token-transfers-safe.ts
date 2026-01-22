import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { encodeFunctionData, parseAbi, toBytes, keccak256, erc20Abi } from 'viem'
import { BaseConfig, Token } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * Configuration for a token transfer
 */
export interface TokenTransferConfig {
  /** Token ticker (must match Token enum key) */
  ticker: Token
  /** Amount to transfer (in human-readable units, e.g., 85000 for 85,000 tokens) */
  amount: number
}

/**
 * Default token transfers configuration
 */
const DEFAULT_TRANSFERS: TokenTransferConfig[] = [
  { ticker: Token.USDC, amount: 85_000 },
  { ticker: Token.USDT, amount: 15_000 },
]

/**
 * @dev Creates a Safe transaction proposal to schedule ERC20 transfers in the SummerTimelockController
 *
 * Token addresses are read from the config file.
 * By default, transfers 85,000 USDC and 15,000 USDT to FOUNDATION_MULTISIG_ADDRESS.
 * Custom transfers can be provided via the transfers parameter.
 *
 * @param transfers Array of token transfers to schedule (defaults to 85k USDC and 15k USDT)
 * @param useBummerConfig Whether to use bummer config
 */
export async function scheduleTokenTransfersSafe(
  transfers: TokenTransferConfig[] = DEFAULT_TRANSFERS,
  useBummerConfig = false,
) {
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

  // Read minDelay from timelock contract
  const timelock = await hre.viem.getContractAt('SummerTimelockController', timelockAddress)
  const minDelay = await timelock.read.getMinDelay()
  console.log(kleur.blue('Timelock minDelay:'), kleur.cyan(`${minDelay.toString()} seconds`))

  // Validate transfers configuration
  if (!transfers || transfers.length === 0) {
    throw new Error('At least one token transfer must be configured')
  }

  // Encode the timelock schedule function call
  const timelockScheduleAbi = parseAbi([
    'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) external',
  ])

  const transactions = []
  const baseTimestamp = Date.now()
  const transferDescriptions: string[] = []

  // Process each token transfer
  for (let i = 0; i < transfers.length; i++) {
    const transfer = transfers[i]
    const tokenAddress = validateAddress(config.tokens[transfer.ticker], transfer.ticker)

    // Get token contract and decimals
    const tokenContract = await hre.viem.getContractAt('IERC20Extended', tokenAddress)
    const decimals = await tokenContract.read.decimals()

    console.log(
      kleur.blue(`${transfer.ticker.toUpperCase()} decimals:`),
      kleur.cyan(decimals.toString()),
    )

    // Calculate amount with proper decimal scaling
    const amount = BigInt(transfer.amount) * BigInt(10 ** Number(decimals))

    console.log(
      kleur.blue(`${transfer.ticker.toUpperCase()} transfer amount:`),
      kleur.cyan(
        `${amount.toString()} (${transfer.amount.toLocaleString()} ${transfer.ticker.toUpperCase()})`,
      ),
    )

    // Encode transfer call
    const transferCalldata = encodeFunctionData({
      abi: erc20Abi,
      functionName: 'transfer',
      args: [multisigAddress, amount],
    })

    // Generate unique salt for this transfer
    const salt = keccak256(toBytes(`${baseTimestamp}-${transfer.ticker}-${i}`))

    // Encode the timelock schedule function call
    const scheduleCalldata = encodeFunctionData({
      abi: timelockScheduleAbi,
      functionName: 'schedule',
      args: [
        tokenAddress, // target: token address
        0n, // value: 0 (ERC20 transfer doesn't need ETH)
        transferCalldata, // data: encoded transfer() call
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
        data: transferCalldata,
        predecessor: '0x0000000000000000000000000000000000000000000000000000000000000000',
        salt: salt,
        delay: minDelay.toString(),
      },
    })

    // Build description for this transfer
    transferDescriptions.push(
      `${transfer.amount.toLocaleString()} ${transfer.ticker.toUpperCase()}`,
    )
  }

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = baseTimestamp

  const description = `Schedule transfers of ${transferDescriptions.join(' and ')} to ${multisigAddress}`

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Schedule Token Transfers in Timelock',
      description: description,
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

  const fileName = `schedule_token_transfers_safe_tx_${timestamp}.json`
  const outputPath = path.join(govV2SetupDir, fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
  console.log(
    kleur.cyan(
      `\nNote: This will schedule the transfers. After the delay (${minDelay.toString()} seconds), the transfers can be executed.`,
    ),
  )
  // Build transfer summary
  const transferSummary = transfers
    .map(
      (t) => `${t.amount.toLocaleString()} ${t.ticker.toUpperCase()} (${config.tokens[t.ticker]})`,
    )
    .join(' and ')

  console.log(kleur.cyan(`Transfers: ${transferSummary} to ${multisigAddress}`))
}

if (require.main === module) {
  scheduleTokenTransfersSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
