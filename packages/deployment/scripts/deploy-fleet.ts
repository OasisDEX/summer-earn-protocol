import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, keccak256, toBytes } from 'viem'
import { createFleetModule, FleetContracts } from '../ignition/modules/fleet'
import { BaseConfig, FleetDefinition, TokenType } from '../types/config-types'
import { deployAaveV3Ark } from './arks/deploy-aavev3-ark'
import { deployCompoundV3Ark } from './arks/deploy-compoundv3-ark'
import { deployERC4626Ark, ERC4626ArkUserInput } from './arks/deploy-erc4626-ark'
import { deployMorphoArk } from './arks/deploy-morpho-ark'
import { deployMorphoVaultArk, MorphoVaultArkUserInput } from './arks/deploy-morpho-vault-ark'
import { deploySkyUsdsArk, SkyUsdsArkUserInput } from './arks/deploy-sky-usds-ark'
import { deploySkyUsdsPsm3Ark, SkyUsdsPsm3ArkUserInput } from './arks/deploy-sky-usds-psm3-ark'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { MAX_UINT256_STRING } from './common/constants'
import { grantCommanderRole } from './common/grant-commander-role'
import { saveFleetDeploymentJson } from './common/save-fleet-deployment-json'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { loadFleetDefinition } from './helpers/fleet-definition-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

/**
 * Deploys all Arks specified in the fleet definition
 * @param {FleetDefinition} fleetDefinition - The fleet definition object
 * @param {BaseConfig} config - The configuration object
 * @returns {Promise<Address[]>} Array of deployed Ark addresses
 */
async function deployArks(
  fleetDefinition: FleetDefinition,
  config: BaseConfig,
): Promise<Address[]> {
  const deployedArks: Address[] = []

  for (const arkConfig of fleetDefinition.arks) {
    console.log(kleur.cyan().bold(`Deploying ${arkConfig.type}...`))

    // Convert fleet definition parameters to Ark deployment parameters
    const arkParams = {
      token: {
        address: config.tokens[arkConfig.params.asset.toLowerCase() as TokenType],
        symbol: arkConfig.params.asset.toLowerCase() as TokenType,
      },
      depositCap: fleetDefinition.depositCap,
      maxRebalanceOutflow: MAX_UINT256_STRING,
      maxRebalanceInflow: MAX_UINT256_STRING,
    }

    let deployedArk

    switch (arkConfig.type) {
      case 'AaveV3Ark':
        deployedArk = await deployAaveV3Ark(config, arkParams)
        break

      case 'CompoundV3Ark': {
        const compoundParams = {
          ...arkParams,
        }
        deployedArk = await deployCompoundV3Ark(config, compoundParams)
        break
      }

      case 'ERC4626Ark': {
        if (!arkConfig.params.vaultName) {
          throw new Error('Vault name is required for ERC4626Ark')
        }
        const erc4626Params: ERC4626ArkUserInput = {
          ...arkParams,
          vaultId:
            config.protocolSpecific.erc4626[arkConfig.params.asset.toLowerCase() as TokenType][
              arkConfig.params.vaultName
            ],
          vaultName: arkConfig.params.vaultName,
        }
        deployedArk = await deployERC4626Ark(config, erc4626Params)
        break
      }

      case 'MorphoArk': {
        const morphoParams = {
          ...arkParams,
          marketId:
            config.protocolSpecific.morpho.markets[
              arkConfig.params.asset.toLowerCase() as TokenType
            ][arkConfig.params.vaultName!],
          // todo: validate
          marketName: arkConfig.params.vaultName!,
        }
        deployedArk = await deployMorphoArk(config, morphoParams)
        break
      }

      case 'MorphoVaultArk': {
        const morphoVaultParams: MorphoVaultArkUserInput = {
          ...arkParams,
          vaultId:
            config.protocolSpecific.morpho.vaults[
              arkConfig.params.asset.toLowerCase() as TokenType
            ][arkConfig.params.vaultName!],
          vaultName: arkConfig.params.vaultName!,
        }
        deployedArk = await deployMorphoVaultArk(config, morphoVaultParams)
        break
      }

      // case 'PendleLPArk': {
      //   const pendleLPParams = {
      //     ...arkParams,
      //     pendleMarket: config.protocolSpecific.pendle.markets[arkConfig.params.asset.toLowerCase() as TokenType]
      //   }
      //   deployedArk = await deployPendleLPArk(config, pendleLPParams)
      //   break
      // }

      // case 'PendlePTArk': {
      //   const pendlePTParams = {
      //     ...arkParams,
      //     pendlePT: config.protocolSpecific.pendle.pts[arkConfig.params.asset.toLowerCase() as TokenType]
      //   }
      //   deployedArk = await deployPendlePTArk(config, pendlePTParams)
      //   break
      // }

      // case 'PendlePtOracleArk': {
      //   const pendlePTOracleParams = {
      //     ...arkParams,
      //     pendleMarket: config.protocolSpecific.pendle.markets[arkConfig.params.asset.toLowerCase() as TokenType],
      //     pendleOracle: config.protocolSpecific.pendle.oracle
      //   }
      //   deployedArk = await deployPendlePTOracleArk(config, pendlePTOracleParams)
      //   break
      // }

      case 'SkyUsdsArk': {
        const skyUsdsParams: SkyUsdsArkUserInput = {
          ...arkParams,
        }
        deployedArk = await deploySkyUsdsArk(config, skyUsdsParams)
        break
      }

      case 'SkyUsdsPsm3Ark': {
        const skyUsdsPsm3Params: SkyUsdsPsm3ArkUserInput = {
          ...arkParams,
        }
        deployedArk = await deploySkyUsdsPsm3Ark(config, skyUsdsPsm3Params)
        break
      }

      default:
        throw new Error(`Unknown Ark type: ${arkConfig.type}`)
    }

    if (!deployedArk?.ark?.address) {
      throw new Error(`Failed to deploy ${arkConfig.type}`)
    }

    deployedArks.push(deployedArk.ark.address as Address)
    console.log(
      kleur.green().bold(`Successfully deployed ${arkConfig.type} at ${deployedArk.ark.address}`),
    )
  }

  return deployedArks
}

/**
 * Main function to deploy a fleet.
 * This function orchestrates the entire deployment process, including:
 * - Loading the fleet definition
 * - Getting core contract addresses
 * - Collecting BufferArk parameters
 * - Deploying the fleet and BufferArk contracts
 * - Logging deployment results
 */
async function deployFleet() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))
  const config = getConfigByNetwork(network)

  console.log(kleur.green().bold('Starting Fleet deployment process...'))

  const fleetDefinition = await getFleetDefinition()
  console.log(kleur.blue('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  const assetAddress = getAssetAddress(fleetDefinition.assetSymbol, config)

  if (await confirmDeployment(fleetDefinition)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    // Deploy all Arks first
    const deployedArkAddresses = await deployArks(fleetDefinition, config)

    // Deploy Fleet with deployed Arks
    const deployedFleet = await deployFleetContracts(fleetDefinition, config, assetAddress)

    // Add each Ark to the Fleet
    for (const arkAddress of deployedArkAddresses) {
      await addArkToFleet(arkAddress, config, hre)
    }

    console.log(kleur.green().bold('Deployment completed successfully!'))

    const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()

    await grantCommanderRole(
      config.deployedContracts.gov.protocolAccessManager.address as Address,
      bufferArkAddress,
      deployedFleet.fleetCommander.address,
      hre,
    )

    logDeploymentResults(deployedFleet)
    saveFleetDeploymentJson(fleetDefinition, deployedFleet, bufferArkAddress)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @returns The loaded fleet definition object.
 */
async function getFleetDefinition(): Promise<FleetDefinition> {
  const fleetsDir = path.resolve(__dirname, '..', 'config', 'fleets')
  const fleetFiles = fs.readdirSync(fleetsDir).filter((file) => file.endsWith('.json'))

  if (fleetFiles.length === 0) {
    throw new Error('No fleet definition files found in the fleets directory.')
  }

  const response = await prompts({
    type: 'select',
    name: 'fleetDefinitionFile',
    message: 'Select the fleet definition file:',
    choices: fleetFiles.map((file) => ({ title: file, value: file })),
  })

  const fleetDefinitionPath = path.resolve(fleetsDir, response.fleetDefinitionFile)
  console.log(kleur.green(`Loading fleet definition from: ${fleetDefinitionPath}`))
  // todo: remove this once we have a details field in the fleet definition
  return { ...loadFleetDefinition(fleetDefinitionPath), details: JSON.stringify('') }
}

/**
 * Retrieves the asset address from the config based on the asset symbol.
 * @param {string} assetSymbol - The symbol of the asset.
 * @param {BaseConfig} config - The configuration object.
 * @returns {string} The address of the asset.
 * @throws {Error} If the asset symbol is not found in the config.
 */
function getAssetAddress(assetSymbol: string, config: BaseConfig): string {
  const assetSymbolLower = assetSymbol.toLowerCase() as keyof typeof config.tokens
  if (!Object.keys(config.tokens).includes(assetSymbolLower)) {
    throw new Error(`No token address for symbol ${assetSymbol} found in config`)
  }
  return config.tokens[assetSymbolLower]
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} fleetDefinition - The fleet definition object.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(fleetDefinition: any): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  return await continueDeploymentCheck()
}

/**
 * Deploys the Fleet and BufferArk contracts using Hardhat Ignition.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {CoreContracts} coreContracts - The core contract addresses.
 * @param {string} asset - The address of the asset.
 * @returns {Promise<FleetContracts>} The deployed fleet contracts.
 */
async function deployFleetContracts(
  fleetDefinition: FleetDefinition,
  config: BaseConfig,
  asset: string,
) {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  const name = fleetDefinition.fleetName.replace(/\W/g, '')
  const fleetModule = createFleetModule(`FleetModule_${name}`)
  const deployedModule = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [`FleetModule_${name}`]: {
        configurationManager: config.deployedContracts.core.configurationManager.address,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails: fleetDefinition.details,
        asset,
        initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
        initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
        depositCap: fleetDefinition.depositCap,
        initialTipRate: fleetDefinition.initialTipRate,
        fleetCommanderRewardsManagerFactory:
          config.deployedContracts.core.fleetCommanderRewardsManagerFactory.address,
      },
    },
    deploymentId,
  })
  await addFleetToHarbor(
    deployedModule.fleetCommander.address,
    config.deployedContracts.core.harborCommand.address as Address,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  return deployedModule
}

/**
 * Logs the results of the deployment, including important addresses and next steps.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
function logDeploymentResults(deployedFleet: FleetContracts) {
  ModuleLogger.logFleet(deployedFleet)

  console.log(kleur.green('Fleet deployment completed successfully!'))
  console.log(
    kleur.yellow('Fleet Commander Address:'),
    kleur.cyan(deployedFleet.fleetCommander.address),
  )
}
async function addFleetToHarbor(
  fleetCommanderAddress: Address,
  harborCommandAddress: Address,
  protocolAccessManagerAddress: Address,
) {
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    keccak256(toBytes('GOVERNOR_ROLE')),
    deployer.account.address,
  ])
  if (hasGovernorRole) {
    const hash = await (
      await hre.viem.getContractAt('HarborCommand' as string, harborCommandAddress)
    ).write.enlistFleetCommander([fleetCommanderAddress])
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
    console.log(kleur.green('Fleet added to Harbor Command successfully!'))
  } else {
    console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.red(
        `Please add the fleet @ ${fleetCommanderAddress} to the Harbor Command (${harborCommandAddress}) via governance`,
      ),
    )
  }
}

// Execute the deployFleet function and handle any errors
deployFleet().catch((error) => {
  console.error(kleur.red('Error during fleet deployment:'))
  console.error(error)
  process.exit(1)
})
