import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'
import { Address, createPublicClient, encodeFunctionData, getAddress, http } from 'viem'
import { base } from 'viem/chains'

// Load environment variables
dotenv.config()

if (!process.env.CURATOR_MULTISIG_ADDRESS) {
  throw new Error('❌ CURATOR_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.CURATOR_MULTISIG_PROPOSER_PRIV_KEY) {
  throw new Error('❌ CURATOR_MULTISIG_PROPOSER_PRIV_KEY not set in environment')
}

const safeAddress = getAddress(process.env.FOUNDATION_MULTISIG_ADDRESS as Address)
// adjusted for the index shift
const GOALS_TO_MARK = [1, 2]
// ABI for SummerVestingWallet
const VESTING_WALLET_ABI = [
  {
    inputs: [],
    name: 'getVestingType',
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    name: 'goalsReached',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'goalNumber', type: 'uint256' }],
    name: 'markGoalReached',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    name: 'goalAmounts',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
]

// ABI for SummerVestingWalletFactory
const VESTING_WALLET_FACTORY_ABI = [
  {
    inputs: [{ name: 'beneficiary', type: 'address' }],
    name: 'vestingWallets',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
]

// Vesting type enum
enum VestingType {
  TeamVesting = 0,
  InvestorExTeamVesting = 1,
}

interface VestingConfig {
  [key: string]: {
    timeBased: string
    goals?: string[]
  }
}

async function loadVestingConfig(): Promise<VestingConfig> {
  const vestingConfigPath = path.join(
    __dirname,
    '../../token-distributions/input/8453/vesting.json',
  )
  return JSON.parse(fs.readFileSync(vestingConfigPath, 'utf-8'))
}

async function checkVestingWallet(
  vestingWalletAddress: Address,
  publicClient: any,
): Promise<{ isTeamVesting: boolean; goalsReached: boolean[]; goalAmounts: bigint[] }> {
  const vestingType = await publicClient.readContract({
    address: vestingWalletAddress,
    abi: VESTING_WALLET_ABI,
    functionName: 'getVestingType',
  })

  const isTeamVesting = vestingType === VestingType.TeamVesting

  if (!isTeamVesting) {
    return { isTeamVesting: false, goalsReached: [], goalAmounts: [] }
  }

  // Get all goals and their status
  const goalsReached: boolean[] = []
  const goalAmounts: bigint[] = []
  let i = 0

  while (true) {
    try {
      const [reached, amount] = await Promise.all([
        publicClient.readContract({
          address: vestingWalletAddress,
          abi: VESTING_WALLET_ABI,
          functionName: 'goalsReached',
          args: [i],
        }),
        publicClient.readContract({
          address: vestingWalletAddress,
          abi: VESTING_WALLET_ABI,
          functionName: 'goalAmounts',
          args: [i],
        }),
      ])
      console.log(`Goal ${i + 1} reached: ${reached}, amount: ${amount}`)

      goalsReached.push(reached)
      goalAmounts.push(amount)
      i++
    } catch (error) {
      // If we get an error, we've reached the end of the goals array
      break
    }
  }

  return { isTeamVesting, goalsReached, goalAmounts }
}

async function createGoalUpdateTransactions(
  vestingWalletAddress: Address,
  goalsReached: boolean[],
): Promise<TransactionBase[]> {
  const transactions: TransactionBase[] = []

  for (const goalNumber of GOALS_TO_MARK) {
    // Check if goal exists and is not already reached
    if (goalNumber <= goalsReached.length && !goalsReached[goalNumber - 1]) {
      const markGoalReachedCalldata = encodeFunctionData({
        abi: VESTING_WALLET_ABI,
        functionName: 'markGoalReached',
        args: [goalNumber],
      })

      transactions.push({
        to: vestingWalletAddress,
        data: markGoalReachedCalldata,
        value: '0',
      })
    }
  }

  return transactions
}

async function main() {
  console.log('🚀 Starting vesting goals update process...\n')

  // Load vesting configuration
  const vestingConfig = await loadVestingConfig()
  const beneficiaries = Object.keys(vestingConfig)

  // Setup public client
  const publicClient = createPublicClient({
    chain: base,
    transport: http(process.env.BASE_RPC_URL),
  })

  // Get vesting wallet factory address
  const vestingWalletFactoryAddress = '0x5f3cd3a45E6B8c2B29DDC80411C58291740E8886' // TODO: Add actual factory address

  const allTransactions: TransactionBase[] = []

  for (const beneficiary of beneficiaries) {
    console.log(`\n🔍 Checking vesting wallet for ${beneficiary}...`)

    // Get vesting wallet address
    const vestingWalletAddress = (await publicClient.readContract({
      address: vestingWalletFactoryAddress,
      abi: VESTING_WALLET_FACTORY_ABI,
      functionName: 'vestingWallets',
      args: [beneficiary],
    })) as Address

    if (vestingWalletAddress === '0x0000000000000000000000000000000000000000') {
      console.log(`⚠️ No vesting wallet found for ${beneficiary}, skipping...`)
      continue
    }
    console.log(`Vesting wallet address: ${vestingWalletAddress}`)

    // Check vesting wallet type and goals
    const { isTeamVesting, goalsReached, goalAmounts } = await checkVestingWallet(
      vestingWalletAddress,
      publicClient,
    )

    if (!isTeamVesting) {
      console.log(`⚠️ ${beneficiary} has non-team vesting wallet, skipping...`)
      continue
    }

    console.log(`\n📊 Vesting wallet status for ${beneficiary}:`)
    console.log(`Goals: ${goalAmounts.length}`)
    console.log(`Reached goals: ${goalsReached.filter(Boolean).length}`)

    // Check which goals need to be marked
    const goalsToMark = GOALS_TO_MARK.filter(
      (goalNumber) => goalNumber <= goalsReached.length && !goalsReached[goalNumber - 1],
    )

    if (goalsToMark.length === 0) {
      console.log(`\n✅ All goals ${GOALS_TO_MARK} already reached for ${beneficiary}, skipping...`)
      continue
    }

    console.log(`\n🎯 Goals to mark for ${beneficiary}: ${goalsToMark.join(', ')}`)

    // Create transactions for unreached goals
    const transactions = await createGoalUpdateTransactions(vestingWalletAddress, goalsReached)

    if (transactions.length > 0) {
      console.log(`\n📝 Created ${transactions.length} goal update transactions`)
      allTransactions.push(...transactions)
    } else {
      console.log(`\n✅ All goals already reached for ${beneficiary}`)
    }
  }

  if (allTransactions.length > 0) {
    // Create Safe transaction JSON
    const safeTransactionsJson = {
      version: '1.0',
      chainId: base.id.toString(),
      createdAt: Date.now(),
      meta: {
        name: 'Vesting Goals Update',
        description: 'Update vesting goals for team vesting wallets',
        txBuilderVersion: '1.18.0',
        createdFromSafeAddress: safeAddress,
        createdFromOwnerAddress: '',
        checksum: '',
      },
      transactions: allTransactions.map((tx) => ({
        to: tx.to,
        value: tx.value || '0',
        data: tx.data,
        contractMethod: null,
        contractInputsValues: null,
      })),
    }

    // Write to file
    const outputPath = path.join(
      __dirname,
      `../../safe-transactions-vesting-goals-${Date.now()}.json`,
    )
    fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))
    console.log(`\n✅ Saved transactions to ${outputPath}`)
  } else {
    console.log(`\n⚠️ No transactions needed`)
  }
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
