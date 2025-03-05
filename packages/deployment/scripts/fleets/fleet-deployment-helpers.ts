import hre from 'hardhat'
import kleur from 'kleur'
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
    throw new Error('Reward tokens and amounts arrays must have the same length')
  }

  const publicClient = await hre.viem.getPublicClient()
  const rewardsManager = await hre.viem.getContractAt(
    'FleetCommanderRewardsManager' as string,
    fleetCommanderRewardsManager,
  )

  for (let i = 0; i < rewardTokens.length; i++) {
    const rewardToken = rewardTokens[i]
    const rewardAmount = rewardAmounts[i]
    const rewardDuration = rewardsDurations[i]

    console.log(kleur.yellow(`Configuring rewards for token ${rewardToken}:`))
    console.log(kleur.yellow(`  Amount: ${rewardAmount}`))
    console.log(kleur.yellow(`  Duration: ${rewardDuration} seconds`))

    // Check if token is already a reward token, if not add it
    try {
      // Check if the token already exists as a reward token
      const isExistingToken = await rewardsManager.read
        .rewardTokensLength()
        .then(async (length) => {
          for (let j = 0; j < Number(length); j++) {
            const token = await rewardsManager.read.rewardTokens([j])
            if (token === rewardToken) return true
          }
          return false
        })

      if (!isExistingToken) {
        console.log(kleur.yellow(`  Adding reward token to rewards manager...`))
        const addTxHash = await rewardsManager.write.addRewardToken([rewardToken])
        await publicClient.waitForTransactionReceipt({ hash: addTxHash })
        console.log(kleur.green(`  Reward token added successfully`))
      }
    } catch (error: unknown) {
      console.log(
        kleur.yellow(
          `  Error checking reward tokens, will attempt to add: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
      try {
        const addTxHash = await rewardsManager.write.addRewardToken([rewardToken])
        await publicClient.waitForTransactionReceipt({ hash: addTxHash })
        console.log(kleur.green(`  Reward token added successfully`))
      } catch (addError: unknown) {
        console.log(
          kleur.red(
            `  Failed to add reward token: ${addError instanceof Error ? addError.message : String(addError)}`,
          ),
        )
        // Continue to approval step as token may already exist
      }
    }

    // Get token contract to approve spending
    const tokenContract = await hre.viem.getContractAt('IERC20' as string, rewardToken)

    // Check and approve token spending by rewards manager
    console.log(kleur.yellow(`  Approving token transfer to rewards manager...`))
    const approveTxHash = await tokenContract.write.approve([
      fleetCommanderRewardsManager,
      rewardAmount,
    ])
    await publicClient.waitForTransactionReceipt({ hash: approveTxHash })

    // Notify reward amount
    console.log(kleur.yellow(`  Notifying reward amount...`))
    const notifyTxHash = await rewardsManager.write.notifyRewardAmount([
      rewardToken,
      rewardAmount,
      BigInt(rewardDuration),
    ])
    await publicClient.waitForTransactionReceipt({ hash: notifyTxHash })

    console.log(kleur.green(`  Successfully configured rewards for token ${rewardToken}`))
  }

  console.log(kleur.green().bold('Fleet rewards setup complete'))
}
