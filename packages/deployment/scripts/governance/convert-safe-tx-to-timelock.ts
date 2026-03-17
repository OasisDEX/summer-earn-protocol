import * as fs from 'fs'
import * as path from 'path'
// @ts-ignore
import prompts from 'prompts'
// @ts-ignore
import hre from 'hardhat'
// @ts-ignore
import kleur from 'kleur'
import { encodeFunctionData, parseAbi, toBytes, keccak256, Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import { validateAddress } from '../helpers/validation'

interface SafeTransaction {
  version: string
  chainId: string
  createdAt: number
  meta: {
    name: string
    description: string
    txBuilderVersion: string
    createdFromSafeAddress: string
    createdFromOwnerAddress: string
    checksum: string
  }
  transactions: Array<{
    to: string
    value: string
    data: string
    contractMethod: any
    contractInputsValues: any
  }>
}

/**
 * Encodes a scheduleBatch call for the Timelock controller
 */
function encodeScheduleBatch(
  targets: string[],
  values: bigint[],
  datas: string[],
  predecessor: `0x${string}`,
  salt: `0x${string}`,
  delay: bigint,
) {
  const timelockScheduleBatchAbi = parseAbi([
    'function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) external',
  ])

  return encodeFunctionData({
    abi: timelockScheduleBatchAbi,
    functionName: 'scheduleBatch',
    args: [targets as Address[], values, datas as `0x${string}`[], predecessor, salt, delay],
  })
}

async function main() {
  console.log(kleur.blue('🏦 Convert Safe Proposal to Timelock Schedule 🏦\n'))

  // 1. Select Network
  const { network } = await prompts({
    type: 'select',
    name: 'network',
    message: 'Select the network',
    choices: [
      { title: 'Mainnet', value: 'mainnet' },
      { title: 'Base', value: 'base' },
      { title: 'Arbitrum', value: 'arbitrum' },
      { title: 'Sonic', value: 'sonic' },
    ],
  })

  if (!network) {
    console.log(kleur.red('No network selected. Exiting.'))
    process.exit(1)
  }

  // Set hardhat network so we can use hre.viem properly if needed, although we are mostly building calldata.
  // Actually, let's just use it to get the config.
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, core: false },
    false,
  ) as BaseConfig

  const foundationMultisig = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisig) {
    throw new Error('FOUNDATION_MULTISIG_ADDRESS environment variable is not set')
  }
  const safeAddress = validateAddress(foundationMultisig, 'FOUNDATION_MULTISIG_ADDRESS')

  const timelockAddress = validateAddress(
    config.deployedContracts.govV2.timelock.address,
    'govV2.timelock',
  )
  console.log(kleur.blue('Timelock Address:'), kleur.cyan(timelockAddress))

  // 2. Select Proposal File
  const proposalsDir = path.join(process.cwd(), 'proposals')
  let safeProposalFiles: string[] = []

  // Recursively find all json files in proposals directory
  function findJsonFiles(dir: string, fileList: string[] = []) {
    if (!fs.existsSync(dir)) return fileList
    const files = fs.readdirSync(dir)
    for (const file of files) {
      const stat = fs.statSync(path.join(dir, file))
      if (stat.isDirectory()) {
        findJsonFiles(path.join(dir, file), fileList)
      } else if (file.endsWith('.json')) {
        fileList.push(path.join(dir, file))
      }
    }
    return fileList
  }

  safeProposalFiles = findJsonFiles(proposalsDir).sort((a, b) => {
    return fs.statSync(b).mtime.getTime() - fs.statSync(a).mtime.getTime()
  })

  if (safeProposalFiles.length === 0) {
    console.log(kleur.yellow('No .json files found in the proposals directory.'))
    process.exit(0)
  }

  const { selectedFile } = await prompts({
    type: 'autocomplete',
    name: 'selectedFile',
    message: 'Select a Safe transaction JSON file',
    choices: safeProposalFiles.map((f) => ({
      title: path.relative(proposalsDir, f),
      value: f,
    })),
  })

  if (!selectedFile) {
    console.log(kleur.red('No file selected. Exiting.'))
    process.exit(1)
  }

  // Load the selected Safe transaction
  const safeTxContent = fs.readFileSync(selectedFile, 'utf-8')
  let originalSafeTx: SafeTransaction
  try {
    originalSafeTx = JSON.parse(safeTxContent)
  } catch (error) {
    console.error(kleur.red('Error parsing JSON file:'), error)
    process.exit(1)
  }

  if (!originalSafeTx.transactions || originalSafeTx.transactions.length === 0) {
    console.log(kleur.yellow('The selected Safe transaction has no transactions.'))
    process.exit(0)
  }

  console.log(
    kleur.blue(`Loaded ${originalSafeTx.transactions.length} transaction(s) from selected file.`),
  )

  // 3. Read minDelay from the network (we can reuse hre for this if network is correct, otherwise we might need publicClient)
  // Let's use createPublicClient from viem to be safe, but since it's hardhat we can use hre.viem if we run via hardhat script.
  // Instead, let's just ask user for delay or read it. We cannot use hre.viem directly if we didn't run with --network.
  // Wait, schedule-token-transfers-safe runs via `hardhat run`. Let's assume this script does too.
  let delay = BigInt(3600 * 24 * 2) // fallback to 2 days
  try {
    // But since it's a safe tx builder mostly meant to be run via tsx or hardhat run, let's just prompt for the delay or fetch via viem.
    const publicClient = await hre.viem.getPublicClient()
    const timelock = await hre.viem.getContractAt('SummerTimelockController', timelockAddress)
    delay = await timelock.read.getMinDelay()
    console.log(kleur.blue('Timelock minDelay:'), kleur.cyan(`${delay.toString()} seconds`))
  } catch (error) {
    console.log(
      kleur.yellow(
        `Warning: Could not fetch timelock delay from network. Using fallback of 48h. Check if you are running with the correct hardhat network, or if the contract exists.`,
      ),
    )
    delay = BigInt(172800) // 2 days
  }

  // 4. Extract data and build the scheduleBatch call
  const targets = originalSafeTx.transactions.map((tx) => tx.to)
  const values = originalSafeTx.transactions.map((tx) => BigInt(tx.value || '0'))
  const payloads = originalSafeTx.transactions.map((tx) => tx.data)

  const predecessor = '0x0000000000000000000000000000000000000000000000000000000000000000'
  const timestamp = Date.now()
  const salt = keccak256(toBytes(`timelock-schedule-${timestamp}`))

  const scheduleBatchCalldata = encodeScheduleBatch(
    targets,
    values,
    payloads,
    predecessor,
    salt,
    delay,
  )

  // 5. Generate the new Safe transaction JSON
  const newSafeTx: SafeTransaction = {
    version: '1.0',
    chainId: originalSafeTx.chainId,
    createdAt: timestamp,
    meta: {
      name: `Timelock Schedule: ${originalSafeTx.meta?.name || 'Wrapped Proposal'}`,
      description: `Schedule execution in Timelock. Original description: ${originalSafeTx.meta?.description || ''}`,
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: safeAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions: [
      {
        to: timelockAddress,
        value: '0',
        data: scheduleBatchCalldata,
        contractMethod: null,
        contractInputsValues: null,
      },
    ],
  }

  // 6. Save payload
  const govV2SetupDir = path.join(proposalsDir, 'gov-v2-setup')
  if (!fs.existsSync(govV2SetupDir)) {
    fs.mkdirSync(govV2SetupDir, { recursive: true })
  }

  const originalFileName = path.basename(selectedFile, '.json')
  const newFileName = `schedule_timelock_${originalFileName}_${timestamp}.json`
  const outputPath = path.join(govV2SetupDir, newFileName)

  fs.writeFileSync(outputPath, JSON.stringify(newSafeTx, null, 2))

  console.log(kleur.green(`\n✅ Saved Timelock Schedule Safe transaction to ${outputPath}`))
  console.log(kleur.yellow(`Target Safe: ${safeAddress}`))
  console.log(kleur.cyan(`Delay configured: ${delay.toString()} seconds`))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
