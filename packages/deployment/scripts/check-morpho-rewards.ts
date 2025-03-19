import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { Address, createWalletClient, encodeAbiParameters, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base, mainnet } from 'viem/chains'
import { FleetDeployment } from '../types/config-types'
import { getFleetDeploymentDir } from './common/fleet-deployment-files-helpers'

interface MorphoDistribution {
  claimable: string
  asset: {
    address: string
    chain_id: number
  }
  distributor: {
    address: string
    chain_id: number
  }
  proof: string[]
}

interface MorphoResponse {
  data: MorphoDistribution[]
}

interface RewardSummary {
  arkAddress: string
  distributorAddress: string
  claimableRaw: string
  claimableFormatted: string
  assetAddress: string
  chainId: number
  harvestCalldata: string
  proof: string[]
}

// Map network names to their chain IDs for Morpho rewards
const NETWORK_CHAIN_IDS: Record<string, number> = {
  mainnet: 1,
  base: 8453,
}

// Add these constants at the top with other constants
const NETWORKS = {
  mainnet: mainnet,
  base: base,
}

// Add the claim function ABI
const claimAbi = [
  {
    name: 'claim',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'reward', type: 'address' },
      { name: 'claimable', type: 'uint256' },
      { name: 'proof', type: 'bytes32[]' },
    ],
    outputs: [{ name: 'amount', type: 'uint256' }],
  },
] as const

function encodeHarvestCalldata(distribution: MorphoDistribution): string {
  const rewardsData = {
    urd: [distribution.distributor.address] as `0x${string}`[],
    rewards: [distribution.asset.address] as `0x${string}`[],
    claimable: [BigInt(distribution.claimable)],
    proofs: [distribution.proof.map((p) => p as `0x${string}`)],
  }

  return encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { type: 'address[]', name: 'urd' },
          { type: 'address[]', name: 'rewards' },
          { type: 'uint256[]', name: 'claimable' },
          { type: 'bytes32[][]', name: 'proofs' },
        ],
      },
    ],
    [rewardsData],
  )
}

async function claimRewards(
  arkAddress: string,
  distribution: MorphoDistribution,
  network: keyof typeof NETWORKS,
) {
  console.log(kleur.blue(`Claiming rewards on ${network}...`))
  const privateKey = process.env.PRIVATE_KEY
  if (!privateKey) {
    throw new Error('PRIVATE_KEY environment variable is not set')
  }

  const account = privateKeyToAccount(`0x${privateKey}` as `0x${string}`)
  console.log(kleur.blue(`Account: ${account.address}`))
  const client = createWalletClient({
    account,
    chain: NETWORKS[network],
    transport: http(network == 'mainnet' ? process.env.MAINNET_RPC_URL : undefined),
  })

  console.log(kleur.blue(`Claiming rewards on ${network}...`))

  try {
    const hash = await client.writeContract({
      address: distribution.distributor.address as Address,
      abi: claimAbi,
      functionName: 'claim',
      args: [
        arkAddress as Address,
        distribution.asset.address as Address,
        BigInt(distribution.claimable),
        distribution.proof as `0x${string}`[],
      ],
    })

    console.log(kleur.green(`Claim transaction sent: ${hash}`))
    return hash
  } catch (error) {
    console.error(kleur.red('Error claiming rewards:'), error)
    throw error
  }
}

async function checkMorphoRewards() {
  const fleetsPath = getFleetDeploymentDir()
  const fleetFiles = fs.readdirSync(fleetsPath)
  const fleetDeployments: FleetDeployment[] = fleetFiles
    .filter((file) => file.endsWith('_deployment.json'))
    .map((file) => JSON.parse(fs.readFileSync(path.join(fleetsPath, file), 'utf-8')))

  console.log(kleur.blue('Checking Morpho rewards for all arks in fleets...\n'))

  for (const fleet of fleetDeployments) {
    // Skip networks we don't support
    if (!NETWORK_CHAIN_IDS[fleet.network]) {
      console.log(
        kleur.yellow(
          `Skipping fleet ${fleet.fleetName}: Network ${fleet.network} not supported for Morpho rewards`,
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

    const rewardsByAsset: Record<string, RewardSummary[]> = {}
    const expectedChainId = NETWORK_CHAIN_IDS[fleet.network]

    for (const arkAddress of fleet.arks) {
      try {
        const response = await fetch(
          `https://rewards.morpho.org/v1/users/${arkAddress}/distributions`,
        )

        if (!response.ok) {
          if (response.status !== 404) {
            throw new Error(`HTTP error! status: ${response.status}`)
          }
          continue
        }

        const data = (await response.json()) as MorphoResponse

        if (data.data && data.data.length > 0) {
          // Filter rewards for the correct chain ID
          const relevantRewards = data.data.filter((d) => d.asset.chain_id === expectedChainId)

          for (const distribution of relevantRewards) {
            const assetKey = distribution.asset.address
            if (!rewardsByAsset[assetKey]) {
              rewardsByAsset[assetKey] = []
            }

            const harvestCalldata = encodeHarvestCalldata(distribution)

            rewardsByAsset[assetKey].push({
              arkAddress,
              distributorAddress: distribution.distributor.address,
              claimableRaw: distribution.claimable,
              claimableFormatted: (Number(distribution.claimable) / 1e18).toFixed(6),
              assetAddress: distribution.asset.address,
              chainId: distribution.asset.chain_id,
              harvestCalldata,
              proof: distribution.proof,
            })
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
    for (const [assetAddress, rewards] of Object.entries(rewardsByAsset)) {
      if (rewards.length > 0) {
        console.log(kleur.yellow(`Asset: ${assetAddress}`))

        // Sort rewards by claimable amount in descending order
        rewards.sort((a, b) => Number(b.claimableFormatted) - Number(a.claimableFormatted))

        // Calculate total claimable for this asset
        const totalClaimable = rewards.reduce(
          (sum, reward) => sum + Number(reward.claimableFormatted),
          0,
        )

        console.table(
          rewards.map((reward, index) => ({
            'Ark Address': reward.arkAddress,
            Claimable: reward.claimableFormatted,
            // 'Harvest Calldata': index === 0 ? reward.harvestCalldata : 'N/A', // Show calldata only for the largest
          })),
        )

        console.log(kleur.green(`Total Claimable: ${totalClaimable.toFixed(6)}\n`))

        // Add claim prompt
        const answer = await askToClaim()
        if (answer.toLowerCase() === 'y') {
          for (const reward of rewards) {
            // await new Promise(resolve => setTimeout(resolve, 50000))
            if (Number(reward.claimableFormatted) < 100) {
              continue
            }
            try {
              await claimRewards(
                reward.arkAddress,
                {
                  claimable: reward.claimableRaw,
                  asset: {
                    address: reward.assetAddress,
                    chain_id: reward.chainId,
                  },
                  distributor: {
                    address: reward.distributorAddress,
                    chain_id: reward.chainId,
                  },
                  proof: reward.proof,
                },
                fleet.network as keyof typeof NETWORKS,
              )
            } catch (error) {
              console.error(kleur.red(`Failed to claim rewards for ${reward.arkAddress}`, error))
            }
          }
        }
      }
    }

    if (Object.keys(rewardsByAsset).length === 0) {
      console.log(kleur.yellow('No claimable rewards found\n'))
    }
  }
}

// Add helper function to prompt for claiming
async function askToClaim(): Promise<string> {
  return new Promise((resolve) => {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout,
    })

    readline.question(
      kleur.yellow('Do you want to claim these rewards? (y/N) '),
      (answer: string) => {
        readline.close()
        resolve(answer)
      },
    )
  })
}

checkMorphoRewards().catch((error) => {
  console.error(kleur.red('Error during Morpho rewards check:'))
  console.error(error instanceof Error ? error.message : 'Unknown error')
  process.exit(1)
})
