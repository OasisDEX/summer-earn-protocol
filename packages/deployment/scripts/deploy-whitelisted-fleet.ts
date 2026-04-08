import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, getAddress, Address as ViemAddress } from 'viem'
import { createFleetWhitelistModule } from '../ignition/modules/fleet-whitelist'
import {
  createRoundsVaultInputModule,
  createRoundsVaultOutputModule,
} from '../ignition/modules/rounds/rounds-vault'
import { createAssetsForwarderModule } from '../ignition/modules/utils/assets-forwarder'
import { ArkType, BaseConfig, FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { ADDRESS_ZERO, GOVERNOR_ROLE } from './common/constants'
import {
  loadFleetDeploymentJson,
  saveFleetDeploymentJson,
} from './common/fleet-deployment-files-helpers'
import { logDeploymentResults } from './fleets/fleet-contracts'
import {
  addFleetToHarbor,
  deployArks,
  getRewardsManagerAddress,
  grantCuratorRole,
  grantKeeperRole,
  grantOperatorRole,
  setupFleetRewards,
} from './fleets/fleet-deployment-helpers'
import { getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  getInstitutionFleetConfigDir,
  promptForInstitutionId,
  updateInstitutionDeployedContracts,
  updateInstitutionFleetEntry,
} from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import {
  validateAddress,
  validateConfigAddressEntry,
  validateString,
  validateToken,
} from './helpers/validation'
import { FleetConfigSchema } from './helpers/zod-schemas'

async function selectInstitutionFleetConfig(
  institutionId: string,
  isBummer: boolean,
): Promise<FleetConfig> {
  const dir = getInstitutionFleetConfigDir(institutionId)
  if (!fs.existsSync(dir)) throw new Error(`No fleets dir found for institution: ${dir}`)
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .filter((f) => (isBummer ? f.includes('.bummer') : !f.includes('.bummer')))
  if (files.length === 0)
    throw new Error(`No ${isBummer ? 'bummer ' : ''}fleet configs found under ${dir}`)
  const { file } = await prompts({
    type: 'select',
    name: 'file',
    message: `Select ${isBummer ? 'bummer ' : ''}fleet config for institution ${institutionId}:`,
    choices: files.map((f) => ({ title: f, value: f })),
  })
  const full = path.join(dir, file)
  const data = JSON.parse(fs.readFileSync(full, 'utf8'))
  const parsed = FleetConfigSchema.parse(data)
  // Preserve optional fields and ensure specific typing for details
  return {
    ...parsed,
    details: typeof parsed.details === 'string' ? parsed.details : JSON.stringify(parsed.details),
  } as unknown as FleetConfig
}

enum WhitelistDeploymentMode {
  NEW_FLEET = 'new_fleet',
  ADD_ARK = 'add_ark',
}

async function main() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const institutionId = await promptForInstitutionId()
  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  // Load base config, then overlay institution-scoped deployedContracts so downstream helpers get correct addresses
  const config = getInstitutionConfigByNetwork(
    network,
    institutionId,
    { gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  // Choose mode similar to deploy-fleet
  const { mode } = await prompts({
    type: 'select',
    name: 'mode',
    message: 'What would you like to do?',
    choices: [
      { title: 'Deploy New Whitelisted Fleet', value: WhitelistDeploymentMode.NEW_FLEET },
      { title: 'Add Ark to Existing Whitelisted Fleet', value: WhitelistDeploymentMode.ADD_ARK },
    ],
  })

  const fleetDefinition = await selectInstitutionFleetConfig(institutionId, useBummerConfig)
  validateToken(config, fleetDefinition.assetSymbol)

  // Gate by InstitutionalVaultRegistry: institution must be registered before continuing
  const registryAddress = config.deployedContracts.core.institutionalVaultRegistry?.address
  if (!registryAddress || registryAddress == ADDRESS_ZERO) {
    console.log(
      kleur.red(
        'InstitutionalVaultRegistry address not found in base config. Please deploy and configure it before proceeding.',
      ),
    )
    return
  }
  try {
    const registry = await hre.viem.getContractAt(
      'InstitutionalVaultRegistry' as string,
      registryAddress as Address,
    )
    const institutionBytes32 = (await registry.read.getBytes32InstitutionId([
      institutionId,
    ])) as Address
    const exists = (await registry.read.exists([institutionBytes32])) as boolean
    if (!exists) {
      console.log(
        kleur.red(
          `Institution '${institutionId}' is not registered in InstitutionalVaultRegistry on this chain. Aborting fleet deployment.`,
        ),
      )
      return
    }
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to verify institution registration in registry: ${e instanceof Error ? e.message : String(e)}`,
      ),
    )
    return
  }

  if (mode === WhitelistDeploymentMode.ADD_ARK) {
    // Load existing deployment for this fleet
    const deploymentData = await loadFleetDeploymentJson(fleetDefinition)
    if (!deploymentData || !deploymentData.fleetAddress) {
      console.log(kleur.red('Error: Could not find deployment data for this fleet.'))
      console.log(kleur.yellow('Please ensure you have deployed this fleet previously.'))
      return
    }

    // Get the fleet commander contract to validate on-chain state
    const fleetCommander = await hre.viem.getContractAt(
      'FleetCommanderWhitelist' as string,
      deploymentData.fleetAddress as Address,
    )

    // Get on-chain arks
    const onChainArks = (await fleetCommander.read.getActiveArks()) as Address[]
    console.log(kleur.blue('On-chain Active Arks:'), kleur.cyan(onChainArks.length.toString()))

    // Get existing arks from deployment file
    const existingArks: string[] = deploymentData.arks || []
    console.log(kleur.blue('Deployment File Arks:'), kleur.cyan(existingArks.length.toString()))

    // Compare on-chain state with deployment file
    if (onChainArks.length !== existingArks.length) {
      console.log(
        kleur.red().bold('ERROR: Mismatch detected between on-chain and deployment file!'),
      )
      console.log(kleur.red(`On-chain arks: ${onChainArks.length}`))
      console.log(kleur.red(`Deployment file arks: ${existingArks.length}`))

      onChainArks.forEach((ark) => {
        if (!existingArks.includes(ark)) {
          console.log(kleur.red(`    Ark ${ark} is not in the deployment file.`))
        }
      })

      existingArks.forEach((ark) => {
        if (!onChainArks.includes(ark as Address)) {
          console.log(kleur.red(`    Ark ${ark} is not on the on-chain.`))
        }
      })

      console.log(kleur.yellow('\nOn-chain arks:'))
      onChainArks.forEach((ark, i) => console.log(kleur.cyan(`  ${i + 1}. ${ark}`)))
      console.log(kleur.yellow('\nDeployment file arks:'))
      existingArks.forEach((ark, i) => console.log(kleur.cyan(`  ${i + 1}. ${ark}`)))

      throw new Error(
        'Deployment file state does not match on-chain state. Please reconcile the deployment file before adding new arks.',
      )
    }

    console.log(
      kleur.green('✓ On-chain state matches deployment file. Safe to proceed with ark addition.'),
    )

    const remainingArksToAdd = existingArks.length
      ? (fleetDefinition.arks || []).slice(existingArks.length)
      : fleetDefinition.arks || []

    if (remainingArksToAdd.length === 0) {
      console.log(kleur.yellow('No new arks to deploy. All arks from config are already deployed.'))
      return
    }

    const newArkFleetDefinition = { ...fleetDefinition, arks: remainingArksToAdd }
    const newlyDeployedArks = await deployArks(newArkFleetDefinition, config)

    for (const arkAddress of newlyDeployedArks) {
      await addArkToFleet(arkAddress as Address, config, hre, fleetDefinition)
    }
    const allArks = [...existingArks, ...newlyDeployedArks.map((ark) => ark.toString())]
    updateInstitutionFleetEntry(
      institutionId,
      useBummerConfig,
      network,
      fleetDefinition.fleetName,
      {
        arks: allArks,
        fleetCommander: deploymentData.fleetAddress,
        bufferArk: deploymentData.bufferArkAddress,
      },
    )
    console.log(kleur.green().bold('Completed Ark addition flow.'))
    return
  }

  console.log(kleur.blue('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  const assetAddress = getAssetAddress(fleetDefinition.assetSymbol, config)

  const proceed = await prompts({
    type: 'confirm',
    name: 'value',
    message: 'Proceed with deployment?',
    initial: true,
  })
  if (!proceed.value) {
    console.log(kleur.red('Deployment cancelled.'))
    return
  }

  // Deploy via whitelist module (FleetCommanderWhitelist)
  const envLabel = useBummerConfig ? 'staging_' : ''
  const name = fleetDefinition.fleetName.replace(/\W/g, '')
  const moduleName = `${envLabel}_${institutionId}_FleetWhitelist_${name}`
  const fleetModule = createFleetWhitelistModule(moduleName)

  // Use addresses directly from merged config (ensures propagation is correct)
  const deployedFleet = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [moduleName]: {
        configurationManager: config.deployedContracts.core.configurationManager.address,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails:
          typeof fleetDefinition.details === 'string'
            ? fleetDefinition.details
            : JSON.stringify(fleetDefinition.details),
        asset: assetAddress,
        initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
        initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
        depositCap: fleetDefinition.depositCap,
        initialTipRate: fleetDefinition.initialTipRate,
        fleetCommanderRewardsManagerFactory: '0x0000000000000000000000000000000000000000',
      },
    },
  })
  // Config already contains institution overrides; debug prints kept terse
  console.log(
    'Using institution ProtocolAccessManager:',
    config.deployedContracts.gov.protocolAccessManager.address,
  )
  console.log(
    'Using institution ConfigurationManager:',
    config.deployedContracts.core.configurationManager.address,
  )

  let forwarderAddress: Address | undefined
  let deployedInputVault: Address | undefined
  let deployedOutputVault: Address | undefined

  if (fleetDefinition.operatorType === 'roundsVaults') {
    // Deploy AssetsForwarder
    console.log(kleur.cyan().bold(`\nDeploying AssetsForwarder...`))
    const forwarderModuleName = `${envLabel}AssetsForwarder_${name}`
    const forwarderModule = createAssetsForwarderModule(forwarderModuleName)
    const deployedForwarder = await hre.ignition.deploy(forwarderModule, {
      parameters: {
        [forwarderModuleName]: {
          accessManager: config.deployedContracts.gov.protocolAccessManager.address,
        },
      },
    })
    forwarderAddress = getAddress(deployedForwarder.assetsForwarder.address)
    console.log(kleur.green(`AssetsForwarder deployed to: ${forwarderAddress}`))

    // update config with forwarder
    config.deployedContracts.core.assetsForwarder = {
      address: forwarderAddress,
    }

    updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'core', {
      assetsForwarder: {
        address: forwarderAddress,
      },
    })

    // Deploy RoundsVaults
    const inputModuleName = `${envLabel}_${institutionId}_RoundsVaultInput_${name}`
    const outputModuleName = `${envLabel}_${institutionId}_RoundsVaultOutput_${name}`

    const inputVaultModule = createRoundsVaultInputModule(inputModuleName)
    const outputVaultModule = createRoundsVaultOutputModule(outputModuleName)

    console.log(kleur.cyan().bold(`\nDeploying RoundsVaults...`))
    const inputVault = await hre.ignition.deploy(inputVaultModule, {
      parameters: {
        [inputModuleName]: {
          targetVault: deployedFleet.fleetCommander.address,
          accessManager: config.deployedContracts.gov.protocolAccessManager.address,
          receiptsURI: `vaults/rounds/input/${fleetDefinition.symbol}`,
        },
      },
    })
    deployedInputVault = getAddress(inputVault.roundsVaultInput.address)

    const outputVault = await hre.ignition.deploy(outputVaultModule, {
      parameters: {
        [outputModuleName]: {
          targetVault: deployedFleet.fleetCommander.address,
          accessManager: config.deployedContracts.gov.protocolAccessManager.address,
          receiptsURI: `vaults/rounds/output/${fleetDefinition.symbol}`,
        },
      },
    })
    deployedOutputVault = getAddress(outputVault.roundsVaultOutput.address)
  }
  const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()
  const deployedArks = await deployArks(fleetDefinition, config)
  // Save initial deployment info without arks; arks will be appended by addArkToFleet calls
  saveFleetDeploymentJson(
    fleetDefinition,
    deployedFleet,
    bufferArkAddress as Address,
    undefined,
    useBummerConfig,
  )

  // Persist institution-scoped fleet entry using the fleet config filename (requested: same name as config)
  const fleetNameKey = fleetDefinition.fleetName
  updateInstitutionFleetEntry(institutionId, useBummerConfig, network, fleetNameKey, {
    fleetCommander: deployedFleet.fleetCommander.address as ViemAddress,
    bufferArk: bufferArkAddress as ViemAddress,
    arks: deployedArks as ViemAddress[],
  })

  // Mirror post-deploy role and harbor steps from deploy-fleet.ts
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManagerV2' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const [deployer] = await hre.viem.getWalletClients()
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])

  if (hasGovernorRole) {
    // Role assignments based on operatorType
    if (
      fleetDefinition.operatorType === 'roundsVaults' &&
      deployedInputVault &&
      deployedOutputVault
    ) {
      // Grant operator role to Input/Output vaults
      await grantOperatorRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleet.fleetCommander.address as Address,
        deployedInputVault,
        hre,
      )
      await grantOperatorRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleet.fleetCommander.address as Address,
        deployedOutputVault,
        hre,
      )

      // Grant keeper role to Input/Output vaults for their own operations
      const keeperToGrant =
        fleetDefinition.keeper && fleetDefinition.keeper !== ADDRESS_ZERO
          ? (fleetDefinition.keeper as Address)
          : (deployer.account.address as Address)

      await grantKeeperRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedInputVault,
        keeperToGrant,
        hre,
      )
      await grantKeeperRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedOutputVault,
        keeperToGrant,
        hre,
      )

      // Whitelist Arks & Target Wallets in AssetsForwarder
      if (forwarderAddress) {
        console.log(kleur.blue('Whitelisting Arks & Target Wallets in AssetsForwarder'))
        const forwarderContract = await hre.viem.getContractAt(
          'AssetsForwarder' as string,
          forwarderAddress,
        )

        for (const arkConfig of fleetDefinition.arks) {
          if (arkConfig.type !== ArkType.WisdomTreeArk) {
            continue
          }
          const token = validateToken(config, arkConfig.params.asset)
          const fundName = validateString(arkConfig.params.fundName, 'fundName')

          const wisdomtreeByToken = config.protocolSpecific?.wisdomtree?.[token]
          if (!wisdomtreeByToken) {
            throw new Error(`WisdomTree config missing for token '${token}'`)
          }

          const targetWallet = validateConfigAddressEntry(
            wisdomtreeByToken[fundName],
            'targetWallet',
            `WisdomTree fund '${fundName}' targetWallet`,
          )
          // todo: remove the forwarder
          if (targetWallet) {
            console.log(
              kleur.blue(`Whitelisting Target Wallet in Assets Forwarder: ${targetWallet}`),
            )
            const whitelistTargetWalletHash = await protocolAccessManager.write.setWhitelisted([
              targetWallet,
              true,
            ])
            await (
              await hre.viem.getPublicClient()
            ).waitForTransactionReceipt({ hash: whitelistTargetWalletHash })
          }
        }

        // Whitelist Deployed Arks addresses
        for (const ark of deployedArks) {
          const whitelistArkHash = await protocolAccessManager.write.setWhitelisted([
            ark as Address,
            true,
          ])
          await (
            await hre.viem.getPublicClient()
          ).waitForTransactionReceipt({ hash: whitelistArkHash })
        }
      }
    } else {
      // operatorType === 'admiralsQuarters'
      // Grant operator role to AdmiralsQuarters contract
      const aqAddress = validateAddress(
        config.deployedContracts.core.admiralsQuarters?.address,
        'institution admiralsQuarters',
      )
      await grantOperatorRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleet.fleetCommander.address as Address,
        aqAddress,
        hre,
      )
    }

    // Use unified helper to grant role, add ark to fleet, and update deployment JSON
    for (const arkAddress of deployedArks) {
      await addArkToFleet(arkAddress as Address, config, hre, fleetDefinition)
    }

    // Grant curator role if curator is specified
    if (fleetDefinition.curator && fleetDefinition.curator !== ADDRESS_ZERO) {
      await grantCuratorRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleet.fleetCommander.address as Address,
        fleetDefinition.curator as Address,
        hre,
      )
    }
    if (fleetDefinition.keeper && fleetDefinition.keeper !== ADDRESS_ZERO) {
      await grantKeeperRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleet.fleetCommander.address as Address,
        fleetDefinition.keeper as Address,
        hre,
      )
    }
  } else {
    console.log(
      kleur.yellow(
        'Deployer does not have governor role. Please run governance flow to enlist fleet and grant commander roles.',
      ),
    )
  }

  // Optional rewards setup
  if (
    fleetDefinition.rewardTokens &&
    fleetDefinition.rewardAmounts &&
    fleetDefinition.rewardsDuration
  ) {
    try {
      const rewardsManagerAddress = await getRewardsManagerAddress(
        deployedFleet.fleetCommander.address as ViemAddress,
      )
      await setupFleetRewards(
        rewardsManagerAddress,
        fleetDefinition.rewardTokens.map((t) => t as ViemAddress),
        fleetDefinition.rewardAmounts.map((a) => BigInt(a)),
        Array(fleetDefinition.rewardTokens.length).fill(fleetDefinition.rewardsDuration),
      )
    } catch (e) {
      console.error(
        kleur.red(`Error setting up fleet rewards: ${e instanceof Error ? e.message : String(e)}`),
      )
    }
  }

  logDeploymentResults(deployedFleet)
  console.log(kleur.green().bold('Whitelisted fleet deployed for institution.'))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
