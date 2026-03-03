import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, Address as ViemAddress } from 'viem'
import { createFleetWhitelistModule } from '../ignition/modules/fleet-whitelist'
import {
  createRoundsVaultInputModule,
  createRoundsVaultOutputModule,
} from '../ignition/modules/rounds/rounds-vault'
import { BaseConfig, FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { ADDRESS_ZERO, GOVERNOR_ROLE } from './common/constants'
import { saveFleetDeploymentJson } from './common/fleet-deployment-files-helpers'
import { logDeploymentResults } from './fleets/fleet-contracts'
import {
  addFleetToHarbor,
  deployArks,
  grantCuratorRole,
  grantKeeperRole,
} from './fleets/fleet-deployment-helpers'
import { getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  getInstitutionFleetConfigDir,
  promptForInstitutionId,
  updateInstitutionFleetEntry,
} from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateToken } from './helpers/validation'
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
  // Preserve optional curator if present in raw data (schema may not include it)
  return parsed as unknown as FleetConfig
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
      { title: 'Deploy New Rounds Whitelisted Fleet', value: WhitelistDeploymentMode.NEW_FLEET },
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
  const moduleName = `${envLabel}RoundsFleetWhitelist_${name}`
  const fleetModule = createFleetWhitelistModule(moduleName)

  // Use addresses directly from merged config (ensures propagation is correct)
  const deployedFleet = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [moduleName]: {
        configurationManager: config.deployedContracts.core.configurationManager.address,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails: JSON.stringify(fleetDefinition.details),
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

  const deployedFleetContent = deployedFleet as any

  const { test } = deployedFleetContent
  console.log(kleur.blue(`Deployed Fleet: ${JSON.stringify(test, null, 2)}`))

  const bufferArkAddress = await deployedFleetContent.fleetCommanderWhitelist.read.bufferArk()
  // Deploys WisdomTree Ark using standard helper
  const deployedArks = await deployArks(fleetDefinition, config)

  // Deploy RoundsVaults
  const inputModuleName = `${envLabel}RoundsVaultInput_${name}`
  const outputModuleName = `${envLabel}RoundsVaultOutput_${name}`

  const inputVaultModule = createRoundsVaultInputModule(inputModuleName)
  const outputVaultModule = createRoundsVaultOutputModule(outputModuleName)

  console.log(kleur.cyan().bold(`\nDeploying RoundsVaults...`))
  const { roundsVaultInput: deployedInputVault } = await hre.ignition.deploy(inputVaultModule, {
    parameters: {
      [inputModuleName]: {
        targetVault: deployedFleetContent.fleetCommanderWhitelist.address,
        accessManager: config.deployedContracts.gov.protocolAccessManager.address,
        receiptsURI: `vaults/rounds/input/${fleetDefinition.symbol}`,
      },
    },
  })
  const { roundsVaultOutput: deployedOutputVault } = await hre.ignition.deploy(outputVaultModule, {
    parameters: {
      [outputModuleName]: {
        targetVault: deployedFleetContent.fleetCommanderWhitelist.address,
        accessManager: config.deployedContracts.gov.protocolAccessManager.address,
        receiptsURI: `vaults/rounds/output/${fleetDefinition.symbol}`,
      },
    },
  })

  // Wrap to match saver/logger expected shape
  const deployedCompat = { fleetCommander: deployedFleetContent.fleetCommanderWhitelist } as any

  // Save initial deployment info without arks; arks will be appended by addArkToFleet calls
  saveFleetDeploymentJson(
    fleetDefinition,
    deployedCompat,
    bufferArkAddress as Address,
    undefined,
    useBummerConfig,
  )

  // Persist institution-scoped fleet entry using the fleet config filename (requested: same name as config)
  console.log(`Deployed arks: ${JSON.stringify(deployedArks)}`)

  const fleetNameKey = fleetDefinition.fleetName
  updateInstitutionFleetEntry(institutionId, useBummerConfig, network, fleetNameKey, {
    fleetCommander: deployedFleetContent.fleetCommanderWhitelist.address as ViemAddress,
    bufferArk: bufferArkAddress as ViemAddress,
    arks: deployedArks as ViemAddress[],
  })

  // Mirror post-deploy role and harbor steps from deploy-fleet.ts
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const [deployer] = await hre.viem.getWalletClients()
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])

  if (hasGovernorRole) {
    // Enlist fleet in Harbor
    await addFleetToHarbor(
      deployedFleetContent.fleetCommanderWhitelist.address as Address,
      config.deployedContracts.core.harborCommand.address as Address,
      config.deployedContracts.gov.protocolAccessManager.address as Address,
    )

    // Use unified helper to grant role, add ark to fleet, and update deployment JSON
    for (const arkAddress of deployedArks) {
      await addArkToFleet(arkAddress as Address, config, hre, fleetDefinition)
    }

    // Grant keeper roles to vaults so they can be keepers of their operations
    await grantKeeperRole(
      config.deployedContracts.gov.protocolAccessManager.address as Address,
      (deployedInputVault as any).roundsVaultInput.address as Address,
      fleetDefinition.keeper || (deployer.account.address as Address),
      hre,
    )
    await grantKeeperRole(
      config.deployedContracts.gov.protocolAccessManager.address as Address,
      (deployedOutputVault as any).roundsVaultOutput.address as Address,
      fleetDefinition.keeper || (deployer.account.address as Address),
      hre,
    )

    // Whitelist Vaults
    console.log(kleur.blue('Whitelisting RoundsVaults on FleetCommander'))
    const fleetCommanderContract = await hre.viem.getContractAt(
      'FleetCommanderWhitelist' as string,
      deployedFleetContent.fleetCommanderWhitelist.address as Address,
    )

    let whitelistHash = await fleetCommanderContract.write.setWhitelisted([
      (deployedInputVault as any).roundsVaultInput.address as Address,
      true,
    ])
    await (await hre.viem.getPublicClient()).waitForTransactionReceipt({ hash: whitelistHash })

    whitelistHash = await fleetCommanderContract.write.setWhitelisted([
      (deployedOutputVault as any).roundsVaultOutput.address as Address,
      true,
    ])
    await (await hre.viem.getPublicClient()).waitForTransactionReceipt({ hash: whitelistHash })

    console.log(kleur.blue('Enabling Fleet Token Transferability'))
    const transferabilityHash = await fleetCommanderContract.write.setFleetTokenTransferability()
    await (
      await hre.viem.getPublicClient()
    ).waitForTransactionReceipt({ hash: transferabilityHash })

    console.log(kleur.green('Vaults whitelisted and transferability enabled'))

    // Grant curator role if curator is specified
    if (fleetDefinition.curator) {
      await grantCuratorRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        deployedFleetContent.fleetCommanderWhitelist.address as Address,
        fleetDefinition.curator as Address,
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

  logDeploymentResults(deployedCompat)
  console.log(kleur.green().bold('Rounds Whitelisted fleet deployed for institution.'))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
