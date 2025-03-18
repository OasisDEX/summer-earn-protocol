import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { encodeAbiParameters } from 'viem'
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
  claimableRaw: string
  claimableFormatted: string
  assetAddress: string
  chainId: number
  harvestCalldata: string
}

// Map network names to their chain IDs for Morpho rewards
const NETWORK_CHAIN_IDS: Record<string, number> = {
  mainnet: 1,
  base: 8453,
}

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
              claimableRaw: distribution.claimable,
              claimableFormatted: (Number(distribution.claimable) / 1e18).toFixed(6),
              assetAddress: distribution.asset.address,
              chainId: distribution.asset.chain_id,
              harvestCalldata,
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
            'Harvest Calldata': index === 0 ? reward.harvestCalldata : 'N/A', // Show calldata only for the largest
          })),
        )

        console.log(kleur.green(`Total Claimable: ${totalClaimable.toFixed(6)}\n`))
      }
    }

    if (Object.keys(rewardsByAsset).length === 0) {
      console.log(kleur.yellow('No claimable rewards found\n'))
    }
  }
}

checkMorphoRewards().catch((error) => {
  console.error(kleur.red('Error during Morpho rewards check:'))
  console.error(error instanceof Error ? error.message : 'Unknown error')
  process.exit(1)
})
