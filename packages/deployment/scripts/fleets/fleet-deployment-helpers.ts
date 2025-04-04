import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { deployArk } from '../common/ark-deployment'
import { GOVERNOR_ROLE } from '../common/constants'

/**
 * Deploys all Arks specified in the fleet definition
 * @param {FleetConfig} fleetDefinition - The fleet definition object
 * @param {BaseConfig} config - The configuration object
 * @returns {Promise<Address[]>} Array of deployed Ark addresses
 */
export async function deployArks(
  fleetDefinition: FleetConfig,
  config: BaseConfig,
): Promise<Address[]> {
  const deployedArks: Address[] = []
  const MAX_RETRIES = 5
  const DELAY = 13000 // 13 seconds

  for (const arkConfig of fleetDefinition.arks) {
    console.log(
      kleur.bgWhite().bold(`\n ------------------------------------------------------------`),
    )
    console.log(kleur.cyan().bold(`\nDeploying ${arkConfig.type}...`))

    let retries = 0
    while (retries <= MAX_RETRIES) {
      try {
        const arkAddress = await deployArk(arkConfig, config, fleetDefinition.depositCap)
        deployedArks.push(arkAddress)
        console.log(kleur.green().bold(`Successfully deployed ${arkConfig.type} at ${arkAddress}`))
        break
      } catch (error) {
        if (retries === MAX_RETRIES) {
          console.error(
            kleur.red().bold(`Failed to deploy ${arkConfig.type} after ${MAX_RETRIES} attempts`),
          )
          throw error
        }

        retries++
        console.log(
          kleur.yellow().bold(`Deployment attempt ${retries} failed, retrying in 13 seconds...`),
        )
        await new Promise((resolve) => setTimeout(resolve, DELAY))
      }
    }
  }

  return deployedArks
}

/**
 * Add a fleet to Harbor Command
 */
export async function addFleetToHarbor(
  fleetCommanderAddress: Address,
  harborCommandAddress: Address,
  protocolAccessManagerAddress: Address,
) {
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  console.log('Deployer: ', deployer.account.address)
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])
  if (hasGovernorRole) {
    const harborCommand = await hre.viem.getContractAt(
      'HarborCommand' as string,
      harborCommandAddress,
    )
    const isEnlisted = await harborCommand.read.activeFleetCommanders([fleetCommanderAddress])
    if (!isEnlisted) {
      const hash = await harborCommand.write.enlistFleetCommander([fleetCommanderAddress])
      await publicClient.waitForTransactionReceipt({
        hash: hash,
      })
      console.log(kleur.green('Fleet added to Harbor Command successfully!'))
    } else {
      console.log(kleur.yellow('Fleet already enlisted in Harbor Command'))
    }
  } else {
    console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.red(
        `Please add the fleet @ ${fleetCommanderAddress} to the Harbor Command (${harborCommandAddress}) via governance`,
      ),
    )
  }
}

/**
 * Grant curator role to an account for a fleet
 */
export async function grantCuratorRole(
  protocolAccessManagerAddress: Address,
  fleetCommanderAddress: Address,
  curatorAddress: Address,
  hre: any,
) {
  const publicClient = await hre.viem.getPublicClient()
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )

  console.log(
    kleur.blue('Granting CURATOR_ROLE to'),
    kleur.cyan(curatorAddress),
    kleur.blue('for fleet'),
    kleur.cyan(fleetCommanderAddress),
  )
  const hash = await protocolAccessManager.write.grantCuratorRole([
    fleetCommanderAddress,
    curatorAddress,
  ])
  await publicClient.waitForTransactionReceipt({ hash })
  console.log(kleur.green('CURATOR_ROLE granted successfully!'))
}

/**
 * Configures initial rewards for a fleet's reward manager
 * @param fleetCommanderRewardsManager Address of the rewards manager contract
 * @param rewardTokens Array of reward token addresses
 * @param rewardAmounts Array of reward amounts (must match rewardTokens length)
 * @param rewardsDurations Array of reward durations in seconds (must match rewardTokens length)
 */
export async function setupFleetRewards(
  fleetCommanderRewardsManager: Address,
  rewardTokens: Address[],
  rewardAmounts: bigint[],
  rewardsDurations: number[],
) {
  console.log(kleur.cyan().bold('\nSetting up fleet rewards:'))

  if (rewardTokens.length !== rewardAmounts.length) {
    console.log('rewardTokens', rewardTokens)
    console.log('rewardAmounts', rewardAmounts)
    throw new Error('Reward tokens and amounts arrays must have the same length')
  }

  const publicClient = await hre.viem.getPublicClient()
  console.log('fleetCommanderRewardsManager', fleetCommanderRewardsManager)
  const rewardsManager = await hre.viem.getContractAt(
    'FleetCommanderRewardsManager' as string,
    fleetCommanderRewardsManager,
  )

  console.log('rewardsManager', rewardsManager)

  console.log('rewardTokens', rewardTokens)
  console.log('rewardAmounts', rewardAmounts)
  console.log('rewardsDurations', rewardsDurations)

  for (let i = 0; i < rewardTokens.length; i++) {
    const rewardToken = rewardTokens[i]
    const rewardAmount = rewardAmounts[i]
    const rewardDuration = rewardsDurations[i]

    console.log(kleur.yellow(`Configuring rewards for token ${rewardToken}:`))
    console.log(kleur.yellow(`  Amount: ${rewardAmount}`))
    console.log(kleur.yellow(`  Duration: ${rewardDuration} seconds`))

    // Get token contract to approve spending
    const tokenContract = await hre.viem.getContractAt('IERC20' as string, rewardToken)

    // Check and approve token spending by rewards manager
    console.log(kleur.yellow(`  Approving token transfer to rewards manager...`))
    const approveTxHash = await tokenContract.write.approve([
      fleetCommanderRewardsManager,
      rewardAmount,
    ])
    await publicClient.waitForTransactionReceipt({ hash: approveTxHash })

    // Notify reward amount - this will also add the token if it doesn't exist yet
    console.log(kleur.yellow(`  Notifying reward amount...`))
    try {
      const notifyTxHash = await rewardsManager.write.notifyRewardAmount([
        rewardToken,
        rewardAmount,
        BigInt(rewardDuration),
      ])
      await publicClient.waitForTransactionReceipt({ hash: notifyTxHash })
      console.log(kleur.green(`  Successfully configured rewards for token ${rewardToken}`))
    } catch (error: unknown) {
      console.error(
        kleur.red(
          `  Failed to notify reward amount: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
    }
  }

  console.log(kleur.green().bold('Fleet rewards setup complete'))
}

/**
 * Gets the rewards manager address for a fleet commander
 * @param fleetCommander Address of the FleetCommander
 * @returns Promise<Address> Address of the rewards manager
 */
export async function getRewardsManagerAddress(fleetCommander: Address): Promise<Address> {
  console.log(kleur.yellow(`Getting rewards manager address for fleet ${fleetCommander}...`))

  // Get the default public client
  const publicClient = await hre.viem.getPublicClient()

  const isSonic = hre.network.name === 'sonic'

  const fleetCommanderContract = await hre.viem.getContractAt(
    'FleetCommander' as string,
    fleetCommander,
  )

  // Get the factory address from the fleet commander
  const factoryAddress =
    (await fleetCommanderContract.read.fleetCommanderRewardsManagerFactory()) as Address
  console.log(kleur.blue(`Rewards manager factory: ${factoryAddress}`))

  if (!factoryAddress || factoryAddress === '0x0000000000000000000000000000000000000000') {
    throw new Error('Rewards manager factory not set or invalid')
  }

  try {
    // Get the logs
    const logs = await publicClient.getLogs({
      address: factoryAddress,
      event: {
        type: 'event',
        name: 'RewardsManagerCreated',
        inputs: [
          { type: 'address', name: 'rewardsManager', indexed: true },
          { type: 'address', name: 'fleetCommander', indexed: true },
        ],
      },
      args: {
        fleetCommander: fleetCommander,
      },
      fromBlock: isSonic ? '0xca0d5e' : 'earliest',
    })

    console.log(`Found ${logs.length} logs`)

    if (logs.length === 0) {
      throw new Error(`No rewards manager found for fleet commander ${fleetCommander}`)
    }

    // Get the most recent event if there are multiple
    const mostRecentLog = logs[logs.length - 1]
    const rewardsManagerAddress = mostRecentLog.args.rewardsManager as Address

    // Verify that the rewards manager belongs to the fleet commander
    try {
      const rewardsManagerContract = await hre.viem.getContractAt(
        'FleetCommanderRewardsManager' as string,
        rewardsManagerAddress,
      )
      const linkedFleetCommander = (await rewardsManagerContract.read.fleetCommander()) as Address

      if (linkedFleetCommander.toLowerCase() !== fleetCommander.toLowerCase()) {
        throw new Error(
          `Rewards manager verification failed: linked to ${linkedFleetCommander} instead of ${fleetCommander}`,
        )
      }

      console.log(kleur.green(`Verified rewards manager at ${rewardsManagerAddress}`))
    } catch (error) {
      console.error(
        kleur.red(
          `Failed to verify rewards manager: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
      throw error
    }

    console.log(kleur.green(`Found rewards manager at ${rewardsManagerAddress}`))
    return rewardsManagerAddress
  } catch (error) {
    console.error(
      kleur.red(`Error getting logs: ${error instanceof Error ? error.message : String(error)}`),
    )
    // Print the full error object for debugging
    console.error('Full error:', error)
    throw new Error(
      `Failed to find rewards manager for fleet commander ${fleetCommander}: ${error instanceof Error ? error.message : String(error)}`,
    )
  }
}

/**
 * Lists and allows selection of a fleet deployment from the deployments/fleets directory
 */
export async function promptForFleetDeploymentOutput(
  chainName: string,
): Promise<string | undefined> {
  console.log(kleur.blue('\nLooking for fleet deployments in the deployments/fleets directory...'))

  // The deployments/fleets directory should be in the project root
  const fleetsDir = path.join(process.cwd(), 'deployments', 'fleets')

  if (!fs.existsSync(fleetsDir)) {
    console.log(kleur.yellow('No deployments/fleets directory found'))
    return undefined
  }

  // Find fleet deployments related to the specified chain
  const fleetDeploymentFiles = fs.readdirSync(fleetsDir).filter((file) => {
    // Look for files that might be related to the chain
    return file.toLowerCase().includes(chainName.toLowerCase()) && file.endsWith('.json')
  })

  if (fleetDeploymentFiles.length === 0) {
    console.log(
      kleur.yellow(
        `No fleet deployments found for ${chainName} in the deployments/fleets directory`,
      ),
    )
    return undefined
  }

  // Sort files by date (most recent first)
  fleetDeploymentFiles.sort((a, b) => {
    const statsA = fs.statSync(path.join(fleetsDir, a))
    const statsB = fs.statSync(path.join(fleetsDir, b))
    return statsB.mtime.getTime() - statsA.mtime.getTime()
  })

  // Prompt user to select a fleet deployment
  const { selectedFleet } = await prompts({
    type: 'select',
    name: 'selectedFleet',
    message: 'Select fleet deployment output:',
    choices: [
      { title: 'None', value: 'none' },
      ...fleetDeploymentFiles.map((file) => ({
        title: file,
        value: path.join(fleetsDir, file),
      })),
    ],
  })

  if (selectedFleet === 'none') {
    console.log(kleur.yellow('No fleet deployment selected'))
    return undefined
  }

  console.log(kleur.green(`Selected fleet deployment: ${path.basename(selectedFleet)}`))

  return selectedFleet
}
