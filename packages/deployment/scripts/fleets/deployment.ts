import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import { FleetContracts } from '../../ignition/modules/fleet'
import { BaseConfig, FleetConfig, FleetDeployment } from '../../types/config-types'
import { deployArk } from '../common/ark-deployment'
import { GOVERNOR_ROLE } from '../lib/infrastructure/constants'
import { FleetConfigSchema, FleetDeploymentSchema } from '../lib/infrastructure/zod-schemas'

/**
 * Retrieves available fleets for the current network from the deployments folder.
 * @param  networkName - The name of the current network.
 * @returns An array of fleet objects compatible with the current network.
 */
export function getAvailableFleets(networkName: string): FleetDeployment[] {
  const deploymentsDir = getFleetDeploymentDir()
  const files = fs.readdirSync(deploymentsDir).filter((file) => file.endsWith('_deployment.json'))
  return files
    .map((file) => {
      return loadFleetDeployment(path.join(deploymentsDir, file))
    })
    .filter((fleet) => fleet.network === networkName)
}

/**
 * Loads a fleet deployment from a file.
 * @param filePath - The path to the fleet deployment file.
 * @returns The fleet deployment object.
 * @throws Will throw an error if the file does not exist or cannot be parsed.
 */
export function loadFleetDeployment(filePath: string): FleetDeployment {
  const fullPath = path.resolve(filePath)
  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const parsed = FleetDeploymentSchema.safeParse(JSON.parse(fileContent))
  if (!parsed.success) {
    throw new Error(`Invalid Fleet deployment JSON: ${fullPath} -> ${parsed.error.message}`)
  }
  return parsed.data as unknown as FleetDeployment
}

/**
 * Generates the filename for a fleet deployment based on its name and network.
 * @param fleetDeployment - The fleet deployment or fleet configuration object.
 * @returns The generated filename for the fleet deployment.
 */
export function getFleetDeploymentFileName(fleetDeployment: FleetDeployment | FleetConfig) {
  return `${fleetDeployment.fleetName.replace(/\W/g, '')}_${fleetDeployment.network}_deployment.json`
}

/**
 * Retrieves the directory path for fleet deployment files.
 * @returns The path to the fleet deployment directory.
 */
export function getFleetDeploymentDir() {
  return path.resolve(__dirname, '..', '..', 'deployments', 'fleets')
}

/**
 * Retrieves the directory path for fleet configuration files.
 * @returns The path to the fleet configuration directory.
 */
export function getFleetConfigDir() {
  return path.resolve(__dirname, '..', '..', 'config', 'fleets')
}

/**
 * Constructs the full path to a fleet deployment file.
 * @param fleetDeployment - The fleet deployment or fleet configuration object.
 * @returns The full path to the fleet deployment file.
 */
export function getFleetDeploymentPath(fleetDeployment: FleetDeployment | FleetConfig) {
  return path.join(getFleetDeploymentDir(), getFleetDeploymentFileName(fleetDeployment))
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @param isBummer - Optional parameter to filter for bummer fleet configs
 * @returns The loaded fleet definition object.
 */
export async function getFleetConfig(isBummer?: boolean): Promise<FleetConfig> {
  const fleetsDir = getFleetConfigDir()
  const fleetFiles = fs
    .readdirSync(fleetsDir)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => (isBummer ? file.includes('.bummer') : !file.includes('.bummer')))

  if (fleetFiles.length === 0) {
    throw new Error(
      `No ${isBummer ? 'bummer ' : ''}fleet config files found in the fleets directory.`,
    )
  }

  const response = await prompts({
    type: 'select',
    name: 'fleetConfigFile',
    message: `Select the ${isBummer ? 'bummer ' : ''}fleet config file:`,
    choices: fleetFiles.map((file) => ({ title: file, value: file })),
  })

  const fleetConfigPath = path.resolve(fleetsDir, response.fleetConfigFile)
  console.log(kleur.green(`Loading fleet config from: ${fleetConfigPath}`))
  const fleetConfig = loadFleetConfig(fleetConfigPath)
  return { ...fleetConfig, details: JSON.stringify(fleetConfig.details) }
}

export function loadFleetConfig(filePath: string): FleetConfig {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const parsed = FleetConfigSchema.safeParse(JSON.parse(fileContent))
  if (!parsed.success) {
    throw new Error(`Invalid Fleet config schema: ${fullPath} -> ${parsed.error.message}`)
  }
  return parsed.data as unknown as FleetConfig
}

/**
 * Loads the fleet deployment JSON file for a given fleet definition
 */
export async function loadFleetDeploymentJson(
  fleetDefinition: FleetConfig,
): Promise<FleetDeployment | null> {
  const fleetName = fleetDefinition.fleetName.replace(/\s+/g, '').replace(/\\/g, '')
  const network = hre.network.name
  const fileName = `${fleetName}_${network}_deployment.json`
  const filePath = path.join(process.cwd(), 'deployments', 'fleets', fileName)
  console.log(kleur.green().bold(`Loading fleet deployment output file: ${filePath}`))

  try {
    if (fs.existsSync(filePath)) {
      const fileContent = fs.readFileSync(filePath, 'utf8')
      const parsed = FleetDeploymentSchema.safeParse(JSON.parse(fileContent))
      if (!parsed.success) {
        throw new Error(`Invalid Fleet deployment JSON: ${filePath} -> ${parsed.error.message}`)
      }
      return parsed.data as unknown as FleetDeployment
    }
    return null
  } catch (error) {
    console.error(kleur.red(`Error loading fleet deployment file: ${error}`))
    return null
  }
}

/**
 * Creates and saves a deployment JSON file with fleet information.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
export function saveFleetDeploymentJson(
  fleetDefinition: FleetConfig,
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArks?: Address[],
  isBummer?: boolean,
) {
  const deploymentInfo = {
    fleetName: fleetDefinition.fleetName,
    isBummer: isBummer,
    fleetSymbol: fleetDefinition.symbol,
    assetSymbol: fleetDefinition.assetSymbol,
    fleetAddress: deployedFleet.fleetCommander.address,
    bufferArkAddress: bufferArkAddress.toString(),
    network: fleetDefinition.network,
    initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
    initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
    depositCap: fleetDefinition.depositCap,
    initialTipRate: fleetDefinition.initialTipRate,
    arks: deployedArks?.map((address) => address.toString()),
  }

  // Validate before write
  const validated = FleetDeploymentSchema.parse(deploymentInfo)

  const deploymentDir = getFleetDeploymentDir()
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true })
  }

  const filePath = getFleetDeploymentPath(fleetDefinition)

  if (fs.existsSync(filePath)) {
    console.log(
      kleur.red(`File ${filePath} already exists. Skipping overwriting fleet deployment JSON.`),
    )
  } else {
    fs.writeFileSync(filePath, JSON.stringify(validated, null, 2))
  }

  console.log(kleur.green().bold(`Deployment information saved to: ${filePath}`))
}

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
        console.log('Deploying Ark - fleet deployment helper [Debug]')
        const arkAddress = await deployArk(arkConfig, config, fleetDefinition)
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
          kleur.yellow(error),
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

      console.log('linkedFleetCommander', linkedFleetCommander)
      console.log('fleetCommander', fleetCommander)
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
    console.log('file', file)
    console.log('chainName', chainName)
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

/**
 * Adds the deployed Ark to a selected fleet.
 * @param  arkAddress - The address of the deployed Ark.
 * @param  networkName - The name of the current network.
 * @param  hre - The Hardhat runtime environment.
 */
export async function addArkToFleet(
  arkAddress: Address,
  config: BaseConfig,
  hre: HardhatRuntimeEnvironment,
  fleetDefinition?: FleetConfig,
) {
  let fleet: FleetDeployment | undefined
  console.log(kleur.blue('Adding Ark to fleet...'))
  if (!fleetDefinition) {
    const fleets = getAvailableFleets(hre.network.name)

    if (fleets.length === 0) {
      console.log(kleur.yellow('No compatible fleets found for the current network.'))
      return
    }

    const response = await prompts({
      type: 'select',
      name: 'selectedFleet',
      message: 'Select a fleet to add the Ark to:',
      choices: fleets.map((fleet) => ({
        title: `${fleet.fleetName} (${fleet.network})`,
        value: fleet,
      })),
    })
    fleet = response.selectedFleet
  } else {
    const deploymentsDir = getFleetDeploymentDir()
    const fleetFileName = getFleetDeploymentFileName(fleetDefinition)
    fleet = loadFleetDeployment(path.join(deploymentsDir, fleetFileName))
  }
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  if (fleet) {
    console.log(kleur.blue('Selected fleet:'), kleur.cyan(fleet.fleetName))
    console.log(kleur.blue('Fleet address:'), kleur.cyan(fleet.fleetAddress))

    const deploymentData = fleet

    if (!deploymentData.arks) {
      deploymentData.arks = []
    }

    const fleetContract = await hre.viem.getContractAt(
      'FleetCommander' as string,
      fleet.fleetAddress,
    )

    const isArkAlreadyActive = await fleetContract.read.isArkActiveOrBufferArk([arkAddress])

    if (isArkAlreadyActive) {
      console.log(kleur.red('Ark already added to fleet on-chain. Skipping adding Ark to fleet.'))
      return
    }

    console.log(kleur.blue('Ark not yet added to fleet on-chain. Proceeding with addition...'))

    await grantCommanderRole(
      config.deployedContracts.gov.protocolAccessManager.address as Address,
      arkAddress as Address,
      fleet.fleetAddress as Address,
      hre,
    )

    const protocolAccessManager = await hre.viem.getContractAt(
      'ProtocolAccessManager' as string,
      config.deployedContracts.gov.protocolAccessManager.address as Address,
    )
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      deployer.account.address,
    ])
    if (hasGovernorRole) {
      try {
        const hash = await fleetContract.write.addArk([arkAddress])
        await publicClient.waitForTransactionReceipt({
          hash: hash,
          confirmations: 2,
        })
        console.log(kleur.green('Ark added to fleet successfully!'))
      } catch (error) {
        console.log(kleur.red('Ark already added to fleet. Skipping adding Ark to fleet.'))
      }
    } else {
      console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
      console.log(
        kleur.red(
          `Please add the ark (${arkAddress}) to fleet @ ${fleet.fleetAddress} via governance`,
        ),
      )
    }

    if (!deploymentData.arks.includes(arkAddress)) {
      deploymentData.arks.push(arkAddress)
      const filePath = getFleetDeploymentPath(fleet)
      fs.writeFileSync(filePath, JSON.stringify(deploymentData, null, 2))
      console.log(kleur.green(`Updated fleet deployment JSON at ${filePath}`))
    }

    console.log(kleur.green('Ark added to fleet successfully!'))
  } else {
    console.log(kleur.yellow('No fleet selected. Skipping adding Ark to fleet.'))
  }
}

/**
 * Grants the COMMANDER_ROLE to a Fleet Commander for a specific Ark
 * @param protocolAccessManagerAddress - Address of the ProtocolAccessManager contract
 * @param arkAddress - Address of the Ark contract
 * @param fleetCommanderAddress - Address of the Fleet Commander to receive the role
 * @param hre - Hardhat Runtime Environment
 */
export async function grantCommanderRole(
  protocolAccessManagerAddress: Address,
  arkAddress: Address,
  fleetCommanderAddress: Address,
  hre: HardhatRuntimeEnvironment,
) {
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )

  console.log(
    kleur.yellow(
      `Granting COMMANDER_ROLE to Fleet Commander ${fleetCommanderAddress} for Ark ${arkAddress}`,
    ),
  )

  try {
    // Use the grantCommanderRole function that takes arkAddress and account
    const hash = await protocolAccessManager.write.grantCommanderRole([
      arkAddress,
      fleetCommanderAddress,
    ])

    await publicClient.waitForTransactionReceipt({ hash, confirmations: 2 })
    console.log(kleur.green('Successfully granted COMMANDER_ROLE'))
  } catch (error) {
    console.error(kleur.red('Failed to grant COMMANDER_ROLE:'), error)
    throw error
  }
}
