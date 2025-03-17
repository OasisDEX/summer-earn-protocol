import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { HUB_CHAIN_NAME } from '../common/constants'
import { promptForFleetDeploymentOutput } from '../fleets/fleet-deployment-helpers'
import { createRewardSetupProposal } from '../fleets/fleet-governance-helpers'
import { ChainName } from '../helpers/chain-configs'
import { promptForChain } from '../helpers/chain-prompt'
import { promptForFleet as promptForFleetConfiguration } from '../helpers/fleet-prompt'
import { useTestConfig } from '../helpers/prompt-helpers'

/**
 * Creates a governance proposal to set up fleet rewards.
 */
async function setupFleetRewards() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Determine whether to use test config
  const useBummerConfig = await useTestConfig()

  // Determine if we're running on the hub chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(
    kleur.blue('Chain type:'),
    isHubChain ? kleur.cyan('Hub chain') : kleur.yellow('Satellite chain'),
  )

  // Get config for the current chain
  const { config, chain, rpcUrl } = await promptForChain('Confirm chain configuration:')

  // Prompt for fleet configuration - fix for missing arguments
  const { fleetConfig } = await promptForFleetConfiguration(
    network as ChainName,
    config,
    chain,
    rpcUrl,
  )

  if (!fleetConfig) {
    console.log(kleur.red(`No fleet config found`))
    return
  }

  const fleetDeploymentOutput = await promptForFleetDeploymentOutput(network as ChainName)

  if (!fleetDeploymentOutput) {
    console.log(kleur.red(`No fleet deployment output found for ${network} chain`))
    return
  }

  const fleetDeployment = JSON.parse(fs.readFileSync(fleetDeploymentOutput, 'utf8'))

  const fleetCommanderAddress = fleetDeployment.fleetAddress

  if (!fleetCommanderAddress) {
    console.log(kleur.red(`No fleet commander address found for ${network} chain`))
    return
  }

  console.log(kleur.cyan(`Setting up rewards for ${fleetConfig.fleetName} fleet...`))
  console.log(kleur.blue('Fleet Commander address:'), kleur.cyan(fleetCommanderAddress))

  const rewardTokens: Address[] = fleetConfig.rewardTokens.map((token: string) => token as Address)
  const rewardAmounts: string[] = fleetConfig.rewardAmounts
  const rewardsDuration: number[] = fleetConfig.rewardsDuration

  // Show summary and confirm
  console.log(kleur.cyan('\nFleet Rewards Summary:'))
  console.log(kleur.yellow(`Fleet: ${fleetConfig.fleetName} (${fleetConfig.symbol})`))
  console.log(kleur.yellow(`Fleet Commander: ${fleetCommanderAddress}`))
  console.log(kleur.yellow(`Reward Tokens: ${rewardTokens.length}`))
  for (let i = 0; i < rewardTokens.length; i++) {
    console.log(`  Token ${i + 1}: ${rewardTokens[i]}, Amount: ${rewardAmounts[i]}`)
    console.log(
      kleur.yellow(
        `Reward Duration: ${rewardsDuration[i] / 86400} days (${rewardsDuration[i]} seconds)`,
      ),
    )
  }

  console.log(kleur.yellow(`Cross-chain: ${!isHubChain}`))

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: 'Proceed with creating governance proposal?',
    initial: true,
  })

  if (confirmed) {
    try {
      // Use the createRewardSetupProposal function from fleet-governance-helpers.ts
      await createRewardSetupProposal(
        fleetCommanderAddress,
        rewardTokens,
        rewardAmounts,
        rewardsDuration,
        config,
        fleetConfig,
        useBummerConfig,
        !isHubChain, // isCrossChain = true if not on hub chain
      )

      console.log(kleur.green().bold(`\nProposal creation process completed successfully!`))
    } catch (error: any) {
      console.error(kleur.red('Error creating proposal:'), error)
      if (error.cause?.data) {
        console.error(kleur.red('Error data:'), error.cause.data)
      }
    }
  } else {
    console.log(kleur.red().bold('Operation cancelled by user.'))
  }
}

// Execute the script if called directly
if (require.main === module) {
  setupFleetRewards().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}

export { setupFleetRewards }
