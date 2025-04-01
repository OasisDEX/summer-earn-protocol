import dotenv from 'dotenv'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { Account, createPublicClient, createWalletClient, encodeAbiParameters, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'
import { FleetDeployment } from '../types/config-types'
import { getFleetDeploymentDir } from './common/fleet-deployment-files-helpers'

interface MerklReward {
  root: string
  recipient: string
  proofs: string[]
  token: {
    address: string
    chainId: number
    symbol: string
    decimals: number
  }
  breakdowns: {
    reason: string
    amount: string
    claimed: string
    pending: string
    campaignId: string
  }[]
  claimed: string | null
  amount: string | null
  pending: string | null
}

interface MerklResponse {
  chain: {
    id: number
    name: string
    icon: string
  }
  rewards: MerklReward[]
}

interface RewardSummary {
  arkAddress: string
  tokenAddress: string
  amount: string
  amountFormatted: string
  proofs: string[]
}

const NETWORK_CHAIN_IDS: Record<string, number> = {
  mainnet: 1,
  // Add other networks as needed
}

const MERKL_DISTRIBUTOR: Record<number, `0x${string}`> = {
  1: '0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae', // Mainnet
  // Add other networks as needed
}

function encodeHarvestCalldata(rewards: RewardSummary[]): string {
  const claimData = {
    users: rewards.map((r) => r.arkAddress) as `0x${string}`[],
    tokens: rewards.map((r) => r.tokenAddress) as `0x${string}`[],
    amounts: rewards.map((r) => BigInt(r.amount)),
    proofs: rewards.map((r) => r.proofs.map((p) => p as `0x${string}`)),
  }

  return encodeAbiParameters(
    [
      { type: 'address[]', name: 'users' },
      { type: 'address[]', name: 'tokens' },
      { type: 'uint256[]', name: 'amounts' },
      { type: 'bytes32[][]', name: 'proofs' },
    ],
    [claimData.users, claimData.tokens, claimData.amounts, claimData.proofs],
  )
}

async function claimRewards(chainId: number, rewards: RewardSummary[], account: Account) {
  if (!MERKL_DISTRIBUTOR[chainId]) {
    throw new Error(`No Merkl distributor contract found for chain ID ${chainId}`)
  }

  const publicClient = createPublicClient({
    chain: mainnet,
    transport: http(process.env.MAINNET_RPC_URL),
  })

  const walletClient = createWalletClient({
    account,
    chain: mainnet,
    transport: http(process.env.MAINNET_RPC_URL),
  })

  const claimData = {
    users: rewards.map((r) => r.arkAddress) as `0x${string}`[],
    tokens: rewards.map((r) => r.tokenAddress) as `0x${string}`[],
    amounts: rewards.map((r) => BigInt(r.amount)),
    proofs: rewards.map((r) => r.proofs.map((p) => p as `0x${string}`)),
  }

  try {
    console.log(kleur.blue('Claiming rewards...'))
    console.log(kleur.gray(`Users: ${claimData.users.join(', ')}`))
    console.log(kleur.gray(`Tokens: ${claimData.tokens.join(', ')}`))
    console.log(kleur.gray(`Amounts: ${claimData.amounts.map((a) => a.toString()).join(', ')}`))

    const hash = await walletClient.writeContract({
      address: MERKL_DISTRIBUTOR[chainId],
      abi: [
        {
          name: 'claim',
          type: 'function',
          stateMutability: 'nonpayable',
          inputs: [
            { type: 'address[]', name: 'users' },
            { type: 'address[]', name: 'tokens' },
            { type: 'uint256[]', name: 'amounts' },
            { type: 'bytes32[][]', name: 'proofs' },
          ],
          outputs: [],
        },
      ],
      functionName: 'claim',
      args: [claimData.users, claimData.tokens, claimData.amounts, claimData.proofs],
    })

    console.log(kleur.green(`Claim transaction submitted: ${hash}`))
    return hash
  } catch (error) {
    console.error(kleur.red('Error claiming rewards:'))
    console.error(error instanceof Error ? error.message : 'Unknown error')
    throw error
  }
}

async function checkAnglRewards(shouldClaim = false) {
  // Load environment variables
  dotenv.config()

  let account: Account | undefined
  if (shouldClaim) {
    const PRIVATE_KEY = process.env.PRIVATE_KEY
    if (!PRIVATE_KEY) {
      throw new Error('PRIVATE_KEY environment variable is required for claiming')
    }
    account = privateKeyToAccount(PRIVATE_KEY as `0x${string}`)
  }

  const fleetsPath = getFleetDeploymentDir()
  const fleetFiles = fs.readdirSync(fleetsPath)
  const fleetDeployments: FleetDeployment[] = fleetFiles
    .filter((file) => file.endsWith('_deployment.json'))
    .map((file) => JSON.parse(fs.readFileSync(path.join(fleetsPath, file), 'utf-8')))

  console.log(kleur.blue('Checking ANGL Merkl rewards for all arks in fleets...\n'))

  for (const fleet of fleetDeployments) {
    if (!NETWORK_CHAIN_IDS[fleet.network]) {
      console.log(
        kleur.yellow(
          `Skipping fleet ${fleet.fleetName}: Network ${fleet.network} not supported for ANGL rewards`,
        ),
      )
      continue
    }

    if (!fleet.arks || fleet.arks.length === 0) {
      console.log(kleur.yellow(`Fleet ${fleet.fleetName}: No arks found`))
      continue
    }

    console.log(kleur.cyan().bold(`Fleet: ${fleet.fleetName} (${fleet.network})`))
    console.log(kleur.cyan(`Address: ${fleet.fleetAddress}\n`))

    const rewardsByToken: Record<string, RewardSummary[]> = {}
    const chainId = NETWORK_CHAIN_IDS[fleet.network]

    for (const arkAddress of fleet.arks) {
      try {
        const response = await fetch(
          `https://api.merkl.xyz/v4/users/${arkAddress}/rewards?chainId=${chainId}`,
        )

        if (!response.ok) {
          if (response.status !== 404) {
            throw new Error(`HTTP error! status: ${response.status}`)
          }
          continue
        }

        const data = (await response.json()) as MerklResponse[]

        for (const chainData of data) {
          if (chainData.chain.id === chainId) {
            for (const reward of chainData.rewards) {
              const tokenKey = reward.token.address
              if (!rewardsByToken[tokenKey]) {
                rewardsByToken[tokenKey] = []
              }

              // Sum up all pending amounts from breakdowns
              const totalAmount = reward.breakdowns.reduce(
                (sum, breakdown) => sum + BigInt(breakdown.amount || 0),
                BigInt(0),
              )

              if (totalAmount > 0) {
                rewardsByToken[tokenKey].push({
                  arkAddress,
                  tokenAddress: reward.token.address,
                  amount: totalAmount.toString(),
                  amountFormatted: (Number(totalAmount) / 10 ** reward.token.decimals).toFixed(6),
                  proofs: reward.proofs,
                })
              }
            }
          }
        }
      } catch (error) {
        console.log(
          kleur.red(
            `Error checking rewards for ${arkAddress}: ${error instanceof Error ? error.message : 'Unknown error'}`,
          ),
        )
      }
    }

    // Display results for this fleet
    for (const [tokenAddress, rewards] of Object.entries(rewardsByToken)) {
      if (rewards.length > 0) {
        console.log(kleur.yellow(`Token: ${tokenAddress}`))

        // Sort rewards by amount in descending order
        rewards.sort((a, b) => Number(b.amountFormatted) - Number(a.amountFormatted))

        // Calculate total claimable for this token
        const totalClaimable = rewards.reduce(
          (sum, reward) => sum + Number(reward.amountFormatted),
          0,
        )

        console.table(
          rewards.map((reward) => ({
            'Ark Address': reward.arkAddress,
            'Pending Amount': reward.amountFormatted,
          })),
        )

        // Generate and display harvest calldata for all rewards of this token
        const harvestCalldata = encodeHarvestCalldata(rewards)
        console.log(kleur.magenta('Harvest Calldata:'), harvestCalldata)
        console.log(kleur.green(`Total Pending: ${totalClaimable.toFixed(6)}\n`))
      }
    }

    if (shouldClaim && account) {
      for (const [tokenAddress, rewards] of Object.entries(rewardsByToken)) {
        if (rewards.length > 0) {
          try {
            await claimRewards(chainId, rewards, account)
          } catch (error) {
            console.log(kleur.red(`Failed to claim rewards for token ${tokenAddress}`))
            console.error(error)
          }
        }
      }
    }

    if (Object.keys(rewardsByToken).length === 0) {
      console.log(kleur.yellow('No pending rewards found\n'))
    }
  }
}

// Modify the script execution to accept a --claim flag
const shouldClaim = process.argv.includes('--claim')
checkAnglRewards(shouldClaim).catch((error) => {
  console.error(kleur.red('Error during ANGL rewards check:'))
  console.error(error instanceof Error ? error.message : 'Unknown error')
  process.exit(1)
})
