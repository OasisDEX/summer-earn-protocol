import { createPublicClient, http, formatEther } from 'viem'
import { base } from 'viem/chains'

// Configuration
const SUMMER_STAKING_ADDRESS = '0x6B94fD1Cbf967c6441764a5AcB84eF2B3774c09f' as const
const SUMMER_TOKEN_ADDRESS = '0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32' as const
const SUMMER_PRICE_USD = 0.25 // $0.25 per SUMMER token

// ABI for the rewardData and other functions
const STAKING_ABI = [
  {
    inputs: [{ name: '', type: 'address' }],
    name: 'rewardData',
    outputs: [
      { name: 'periodFinish', type: 'uint256' },
      { name: 'rewardRate', type: 'uint256' },
      { name: 'rewardsDuration', type: 'uint256' },
      { name: 'lastUpdateTime', type: 'uint256' },
      { name: 'rewardPerTokenStored', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'user', type: 'address' }],
    name: 'getUserStakesCount',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'user', type: 'address' },
      { name: 'index', type: 'uint256' },
    ],
    name: 'getUserStake',
    outputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'weightedAmount', type: 'uint256' },
      { name: 'lockupEndTime', type: 'uint256' },
      { name: 'lockupPeriod', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const

async function main() {
  console.log('🔍 Checking Summer Staking APR...\n')

  // Create public client for Base network
  const client = createPublicClient({
    chain: base,
    transport: http('https://mainnet.base.org'),
  })

  try {
    // 1. Get reward data for SUMMER token
    console.log('📊 Fetching reward data...')
    const rewardData = await client.readContract({
      address: SUMMER_STAKING_ADDRESS,
      abi: STAKING_ABI,
      functionName: 'rewardData',
      args: [SUMMER_TOKEN_ADDRESS],
    })

    const [periodFinish, rewardRate, rewardsDuration, lastUpdateTime, rewardPerTokenStored] =
      rewardData

    console.log('📈 Reward Data for SUMMER token:')
    console.log(`   Period Finish: ${new Date(Number(periodFinish) * 1000).toISOString()}`)
    console.log(`   Reward Rate: ${formatEther(rewardRate)} SUMMER/second`)
    console.log(`   Rewards Duration: ${rewardsDuration} seconds`)
    console.log(`   Last Update Time: ${new Date(Number(lastUpdateTime) * 1000).toISOString()}`)
    console.log(`   Reward Per Token Stored: ${formatEther(rewardPerTokenStored)}\n`)

    // 2. Get total staked supply (weighted)
    console.log('💰 Fetching total staked supply...')
    const totalSupply = await client.readContract({
      address: SUMMER_STAKING_ADDRESS,
      abi: STAKING_ABI,
      functionName: 'totalSupply',
    })

    console.log(`   Total Weighted Supply: ${formatEther(totalSupply)} (weighted SUMMER units)\n`)

    // 3. Check some sample stakes to understand the scale
    console.log('🔍 Checking sample stakes...')
    const sampleAddresses = [
      '0x0000000000000000000000000000000000000000', // zero address
      '0x6B94fD1Cbf967c6441764a5AcB84eF2B3774c09f', // the staking contract itself
    ]

    for (const addr of sampleAddresses) {
      try {
        const stakeCount = await client.readContract({
          address: SUMMER_STAKING_ADDRESS,
          abi: STAKING_ABI,
          functionName: 'getUserStakesCount',
          args: [addr],
        })

        const balance = await client.readContract({
          address: SUMMER_STAKING_ADDRESS,
          abi: STAKING_ABI,
          functionName: 'balanceOf',
          args: [addr],
        })

        console.log(`   Address ${addr}:`)
        console.log(`     Stake Count: ${stakeCount}`)
        console.log(`     Raw Balance: ${formatEther(balance)} SUMMER`)

        if (Number(stakeCount) > 0) {
          for (let i = 0; i < Math.min(Number(stakeCount), 3); i++) {
            const stake = await client.readContract({
              address: SUMMER_STAKING_ADDRESS,
              abi: STAKING_ABI,
              functionName: 'getUserStake',
              args: [addr, BigInt(i)],
            })
            console.log(
              `     Stake ${i}: amount=${formatEther(stake[0])}, weighted=${formatEther(stake[1])}`,
            )
          }
        }
      } catch (e) {
        console.log(`   Address ${addr}: Error - ${e}`)
      }
    }
    console.log()

    // 4. Calculate APR
    console.log('🧮 Calculating APR...')

    // Annual reward amount = rewardRate * seconds in a year
    const SECONDS_PER_YEAR = 365 * 24 * 60 * 60 // 31,536,000 seconds
    const annualRewardAmount = rewardRate * BigInt(SECONDS_PER_YEAR)

    // Annual reward value = annual reward amount * price per token
    const annualRewardValue = Number(formatEther(annualRewardAmount)) * SUMMER_PRICE_USD

    // Total staked value = total weighted supply * price per token
    const totalStakedValue = Number(formatEther(totalSupply)) * SUMMER_PRICE_USD

    // APR = (annual reward value / total staked value) * 100
    const apr = totalStakedValue > 0 ? (annualRewardValue / totalStakedValue) * 100 : 0

    console.log('💹 APR Calculation:')
    console.log(`   Annual Reward Amount: ${formatEther(annualRewardAmount)} SUMMER`)
    console.log(`   Annual Reward Value: $${annualRewardValue.toFixed(2)}`)
    console.log(`   Total Staked Value: $${totalStakedValue.toFixed(2)}`)
    console.log(`   APR: ${apr.toFixed(4)}%\n`)

    // Additional metrics
    console.log('📋 Additional Metrics:')
    console.log(`   Reward Rate per Year: ${formatEther(annualRewardAmount)} SUMMER/year`)
    console.log(
      `   Daily Rewards: ${(Number(formatEther(rewardRate)) * 24 * 60 * 60).toFixed(6)} SUMMER/day`,
    )
    console.log(
      `   Hourly Rewards: ${(Number(formatEther(rewardRate)) * 60 * 60).toFixed(6)} SUMMER/hour`,
    )

    // Check if rewards are still active
    const now = Math.floor(Date.now() / 1000)
    const isActive = Number(periodFinish) > now
    console.log(`   Rewards Active: ${isActive ? '✅ Yes' : '❌ No'}`)

    if (!isActive) {
      console.log(`   Rewards ended: ${new Date(Number(periodFinish) * 1000).toLocaleString()}`)
    }
  } catch (error) {
    console.error('❌ Error fetching staking data:', error)
    process.exit(1)
  }
}

main()
