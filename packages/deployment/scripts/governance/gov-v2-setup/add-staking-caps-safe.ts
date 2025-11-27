import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, parseAbi } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * @dev Creates a Safe transaction proposal to set bucket caps on SummerStaking
 *
 * Bucket caps configuration:
 * - NoLockup: unlimited (type(uint256).max)
 * - ShortTerm: 0 (disabled)
 * - TwoWeeksToThreeMonths: unlimited
 * - ThreeToSixMonths: unlimited
 * - SixToTwelveMonths: unlimited
 * - OneToTwoYears: unlimited
 * - TwoToThreeYears: unlimited
 *
 * Note: Modify the BUCKET_CAPS constant below to customize cap values
 */
const BUCKET_CAPS: Record<string, string> = {
  NoLockup: '15000000000000000000000000', // 15M SUMR
  ShortTerm: '0', // disabled
  TwoWeeksToThreeMonths: '15000000000000000000000000', // 15M SUMR
  ThreeToSixMonths: '22500000000000000000000000', // 22.5M SUMR
  SixToTwelveMonths: '22500000000000000000000000', // 22.5M SUMR
  OneToTwoYears: '50000000000000000000000000', // 50M SUMR
  TwoToThreeYears: '115792089237316195423570985008687907853269984665640564039457584007913129639935', // 115.79M SUMR
}

export async function addStakingCapsSafe(useBummerConfig = false) {
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

  const stakingAddress = validateAddress(
    config.deployedContracts.govV2.summerStaking.address,
    'govV2.summerStaking',
  )

  const staking = await hre.viem.getContractAt('SummerStaking', stakingAddress)

  const transactions = []

  const updateLockupBucketCapAbi = parseAbi([
    'function updateLockupBucketCap(uint8 bucket, uint256 newCap) external',
  ])

  // Bucket enum values (from ISummerStaking)
  const buckets = [
    { name: 'NoLockup', value: 0 },
    { name: 'ShortTerm', value: 1 },
    { name: 'TwoWeeksToThreeMonths', value: 2 },
    { name: 'ThreeToSixMonths', value: 3 },
    { name: 'SixToTwelveMonths', value: 4 },
    { name: 'OneToTwoYears', value: 5 },
    { name: 'TwoToThreeYears', value: 6 },
  ]

  for (const bucket of buckets) {
    const newCap = BigInt(BUCKET_CAPS[bucket.name])

    // Check current cap
    const bucketDetails = await staking.read.getBucketDetails([bucket.value])
    const currentCap = bucketDetails[0] as bigint // cap is first element

    if (currentCap === newCap) {
      console.log(
        kleur.yellow(
          `⚠️  Bucket ${bucket.name} already has cap ${currentCap.toString()}, skipping...`,
        ),
      )
      continue
    }

    transactions.push({
      to: stakingAddress,
      value: '0',
      data: encodeFunctionData({
        abi: updateLockupBucketCapAbi,
        functionName: 'updateLockupBucketCap',
        args: [bucket.value, newCap],
      }),
      contractMethod: {
        inputs: [
          { name: 'bucket', type: 'uint8' },
          { name: 'newCap', type: 'uint256' },
        ],
        name: 'updateLockupBucketCap',
        payable: false,
      },
      contractInputsValues: {
        bucket: bucket.value.toString(),
        newCap: newCap.toString(),
      },
    })
  }

  if (transactions.length === 0) {
    console.log(kleur.green('All bucket caps are already set correctly.'))
    return
  }

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Set Staking Bucket Caps',
      description: `Update ${transactions.length} bucket cap(s) on SummerStaking`,
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions,
  }

  // Ensure proposals directory exists
  const proposalsDir = path.join(process.cwd(), 'proposals')
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
  }

  const fileName = `add_staking_caps_safe_tx_${timestamp}.json`
  const outputPath = path.join(proposalsDir, 'gov-v2-setup', fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
  console.log(
    kleur.cyan(`\nNote: Modify BUCKET_CAPS in the script to customize cap values before running.`),
  )
}

if (require.main === module) {
  addStakingCapsSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
