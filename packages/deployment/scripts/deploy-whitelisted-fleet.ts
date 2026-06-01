import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, getAddress, parseAbi, Address as ViemAddress } from 'viem'
import {
  createFleetWhitelistModule,
  FleetWhitelistContracts,
} from '../ignition/modules/fleet-whitelist'
import {
  createRoundsVaultInputModule,
  createRoundsVaultOutputModule,
} from '../ignition/modules/rounds/rounds-vault'
import { BaseConfig, FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { ADDRESS_ZERO, GOVERNOR_ROLE } from './common/constants'
import {
  loadFleetDeploymentJson,
  saveFleetDeploymentJson,
} from './common/fleet-deployment-files-helpers'
import { GovernorAction, GovernorActionBatch } from './common/governor-actions'
import { logDeploymentResults } from './fleets/fleet-contracts'
import {
  buildAddArkAction,
  buildEnlistFleetAction,
  buildGrantCommanderRoleAction,
  buildGrantCuratorRoleAction,
  buildGrantKeeperRoleAction,
  buildGrantOperatorRoleAction,
  deployArks,
  getRewardsManagerAddress,
  setupFleetRewards,
} from './fleets/fleet-deployment-helpers'

const ROUNDS_VAULT_REGISTRY_ABI = parseAbi([
  'function registerPair(bytes32 institutionId, address targetVault, address inputVault, address outputVault)',
  'function getPairId(address targetVault) view returns (bytes32)',
  'function exists(bytes32 pairId) view returns (bool)',
])

// ContractSpecificRoles enum positions (must match access-contracts IProtocolAccessManager.sol)
const CONTRACT_SPECIFIC_ROLES = {
  CURATOR: 0,
  KEEPER: 1,
  COMMANDER: 2,
  OPERATOR: 3,
} as const

type ContractRole = (typeof CONTRACT_SPECIFIC_ROLES)[keyof typeof CONTRACT_SPECIFIC_ROLES]
import { getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  getInstitutionFleetConfigDir,
  promptForInstitutionId,
  updateInstitutionFleetEntry,
} from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateAddress, validateToken } from './helpers/validation'
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

  // Gate by InstitutionalVaultRegistry V2: institution must be registered before continuing
  const registryAddress = config.deployedContracts.core.institutionalVaultRegistryV2?.address
  if (!registryAddress || registryAddress == ADDRESS_ZERO) {
    console.log(
      kleur.red(
        'InstitutionalVaultRegistry V2 address not found in base config. Please deploy and configure it before proceeding.',
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
          `Institution '${institutionId}' is not registered in InstitutionalVaultRegistry V2 on this chain. Aborting fleet deployment.`,
        ),
      )
      return
    }
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to verify institution registration in registry V2: ${e instanceof Error ? e.message : String(e)}`,
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
  const moduleName = `${envLabel}${institutionId}_FleetWhitelist_${name}`
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

  let deployedInputVault: Address | undefined
  let deployedOutputVault: Address | undefined
  const isRoundsVault = fleetDefinition.operatorType === 'roundsVaults'
  if (isRoundsVault) {
    // Deploy RoundsVaults
    const inputModuleName = `${envLabel}${institutionId}_RoundsVaultInput_${name}`
    const outputModuleName = `${envLabel}${institutionId}_RoundsVaultOutput_${name}`

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

    fleetDefinition.roundsVaultInput = deployedInputVault
    fleetDefinition.roundsVaultOutput = deployedOutputVault
  }
  const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()
  const deployedArks = await deployArks(fleetDefinition, config)
  // Save initial deployment info without arks; arks will be appended by addArkToFleet calls
  saveFleetDeploymentJson(
    fleetDefinition,
    deployedFleet as FleetWhitelistContracts,
    bufferArkAddress as Address,
    undefined,
    useBummerConfig,
  )
  const additionalRouindsVaultsInfo =
    isRoundsVault && fleetDefinition.roundsVaultInput && fleetDefinition.roundsVaultOutput
      ? ({
          roundsVaultInput: fleetDefinition.roundsVaultInput,
          roundsVaultOutput: fleetDefinition.roundsVaultOutput,
        } as const)
      : undefined

  console.log(additionalRouindsVaultsInfo)
  // Persist institution-scoped fleet entry using the fleet config filename (requested: same name as config)
  const fleetNameKey = fleetDefinition.fleetName
  updateInstitutionFleetEntry(institutionId, useBummerConfig, network, fleetNameKey, {
    fleetCommander: deployedFleet.fleetCommander.address as ViemAddress,
    bufferArk: bufferArkAddress as ViemAddress,
    ...additionalRouindsVaultsInfo,
    arks: deployedArks as ViemAddress[],
  })

  // Mirror post-deploy role and harbor steps from deploy-fleet.ts
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManagerV2' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const [deployer] = await hre.viem.getWalletClients()
  const hasGovernorRole = (await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])) as boolean

  const pamAddress = config.deployedContracts.gov.protocolAccessManager.address as Address
  const fleetAddress = deployedFleet.fleetCommander.address as Address
  const fleetCommanderRead = await hre.viem.getContractAt(
    'FleetCommanderWhitelist' as string,
    fleetAddress,
  )

  // Idempotency helper: returns true when `account` already holds the contract-specific role
  // for `roleName` on `target`. Used to skip redundant grant actions when re-running the script.
  const accountHasContractRole = async (
    roleName: ContractRole,
    target: Address,
    account: Address,
  ): Promise<boolean> => {
    const role = (await protocolAccessManager.read.generateRole([
      roleName,
      target,
    ])) as `0x${string}`
    return (await protocolAccessManager.read.hasRole([role, account])) as boolean
  }

  // Queue a role-grant action only if the account does not yet hold it.
  const queueGrantIfMissing = async (
    label: string,
    roleName: ContractRole,
    target: Address,
    account: Address,
    action: GovernorAction,
  ) => {
    if (await accountHasContractRole(roleName, target, account)) {
      console.log(
        kleur.gray(`[skip] ${label}: already granted (target=${target}, account=${account})`),
      )
      return
    }
    await batch.runOrQueue(action)
  }

  const batch = new GovernorActionBatch(
    hasGovernorRole,
    hre,
    `Fleet ${fleetDefinition.fleetName} governor actions (institution ${institutionId})`,
  )

  // Post-deploy sequence — order matches deploy-fleet.ts so the v2 subgraph
  // sees events in the same order it does for non-whitelist fleets. The
  // critical step is enlistFleetCommander on HarborCommand: the subgraph
  // bootstraps a FleetCommanderTemplate from that event and snapshots
  // getActiveArks() at that block, so addArk calls must precede the enlist.

  // 1. Per-ark: grant COMMANDER on ark to the fleet, then addArk.
  //    (addArk reverts unless the fleet already holds COMMANDER on the ark.)
  for (const arkAddress of deployedArks) {
    await queueGrantIfMissing(
      `COMMANDER on ark ${arkAddress} for fleet`,
      CONTRACT_SPECIFIC_ROLES.COMMANDER,
      arkAddress as Address,
      fleetAddress,
      buildGrantCommanderRoleAction(pamAddress, arkAddress as Address, fleetAddress),
    )

    const arkAlreadyActive = (await fleetCommanderRead.read.isArkActiveOrBufferArk([
      arkAddress,
    ])) as boolean
    if (arkAlreadyActive) {
      console.log(kleur.gray(`[skip] addArk(${arkAddress}): already active on fleet`))
    } else {
      await batch.runOrQueue(buildAddArkAction(fleetAddress, arkAddress as Address))
    }
  }

  // 2. Enlist the fleet on HarborCommand. This is what bootstraps the
  //    FleetCommanderTemplate in the v2 subgraph — without it the fleet is
  //    invisible to the indexer.
  const harborCommandAddress = validateAddress(
    config.deployedContracts.core.harborCommand?.address,
    'institution harborCommand',
  ) as Address
  const harborCommandRead = await hre.viem.getContractAt(
    'HarborCommand' as string,
    harborCommandAddress,
  )
  const fleetAlreadyEnlisted = (await harborCommandRead.read.activeFleetCommanders([
    fleetAddress,
  ])) as boolean
  if (fleetAlreadyEnlisted) {
    console.log(kleur.gray(`[skip] enlistFleetCommander(${fleetAddress}): already enlisted`))
  } else {
    await batch.runOrQueue(buildEnlistFleetAction(harborCommandAddress, fleetAddress))
  }

  // 3. COMMANDER on bufferArk for the fleet (matches deploy-fleet.ts position
  //    after enlist). Needed at first user deposit, not at enlist time.
  await queueGrantIfMissing(
    'COMMANDER on bufferArk for fleet',
    CONTRACT_SPECIFIC_ROLES.COMMANDER,
    bufferArkAddress as Address,
    fleetAddress,
    buildGrantCommanderRoleAction(pamAddress, bufferArkAddress as Address, fleetAddress),
  )

  // 4. Curator (if configured).
  if (fleetDefinition.curator && fleetDefinition.curator !== ADDRESS_ZERO) {
    await queueGrantIfMissing(
      'CURATOR on fleet',
      CONTRACT_SPECIFIC_ROLES.CURATOR,
      fleetAddress,
      fleetDefinition.curator as Address,
      buildGrantCuratorRoleAction(pamAddress, fleetAddress, fleetDefinition.curator as Address),
    )
  }

  // 5. Keeper on fleet (if configured) — whitelist-specific extension.
  if (fleetDefinition.keeper && fleetDefinition.keeper !== ADDRESS_ZERO) {
    await queueGrantIfMissing(
      'KEEPER on fleet',
      CONTRACT_SPECIFIC_ROLES.KEEPER,
      fleetAddress,
      fleetDefinition.keeper as Address,
      buildGrantKeeperRoleAction(pamAddress, fleetAddress, fleetDefinition.keeper as Address),
    )
  }

  // 6. Operator/keeper grants — whitelist-specific. For rounds-vaults flow,
  //    the fleet operates input/output vaults; for non-rounds flow, AdmiralsQuarters
  //    operates the fleet directly.
  if (
    fleetDefinition.operatorType === 'roundsVaults' &&
    deployedInputVault &&
    deployedOutputVault
  ) {
    await queueGrantIfMissing(
      'OPERATOR on input rounds-vault',
      CONTRACT_SPECIFIC_ROLES.OPERATOR,
      fleetAddress,
      deployedInputVault,
      buildGrantOperatorRoleAction(pamAddress, fleetAddress, deployedInputVault),
    )
    await queueGrantIfMissing(
      'OPERATOR on output rounds-vault',
      CONTRACT_SPECIFIC_ROLES.OPERATOR,
      fleetAddress,
      deployedOutputVault,
      buildGrantOperatorRoleAction(pamAddress, fleetAddress, deployedOutputVault),
    )

    const keeperToGrant =
      fleetDefinition.keeper && fleetDefinition.keeper !== ADDRESS_ZERO
        ? (fleetDefinition.keeper as Address)
        : (deployer.account.address as Address)

    await queueGrantIfMissing(
      'KEEPER on input rounds-vault',
      CONTRACT_SPECIFIC_ROLES.KEEPER,
      deployedInputVault,
      keeperToGrant,
      buildGrantKeeperRoleAction(pamAddress, deployedInputVault, keeperToGrant),
    )
    await queueGrantIfMissing(
      'KEEPER on output rounds-vault',
      CONTRACT_SPECIFIC_ROLES.KEEPER,
      deployedOutputVault,
      keeperToGrant,
      buildGrantKeeperRoleAction(pamAddress, deployedOutputVault, keeperToGrant),
    )
  } else {
    const aqAddress = validateAddress(
      config.deployedContracts.core.admiralsQuarters?.address,
      'institution admiralsQuarters',
    )
    await queueGrantIfMissing(
      'OPERATOR for AdmiralsQuarters on fleet',
      CONTRACT_SPECIFIC_ROLES.OPERATOR,
      fleetAddress,
      aqAddress as Address,
      buildGrantOperatorRoleAction(pamAddress, fleetAddress, aqAddress as Address),
    )
  }

  // Register the rounds-vault pair so the subgraph can discover it.
  if (
    fleetDefinition.operatorType === 'roundsVaults' &&
    deployedInputVault &&
    deployedOutputVault
  ) {
    const roundsRegistryAddress = config.deployedContracts.core.roundsVaultRegistry?.address
    if (!roundsRegistryAddress || roundsRegistryAddress === ADDRESS_ZERO) {
      throw new Error(
        'roundsVaultRegistry not deployed for this network — run `pnpm deploy:rounds-vault-registry` first.',
      )
    }

    const institutionRegistry = await hre.viem.getContractAt(
      'InstitutionalVaultRegistry' as string,
      registryAddress as Address,
    )
    const institutionIdBytes32 = (await institutionRegistry.read.getBytes32InstitutionId([
      institutionId,
    ])) as `0x${string}`

    // Idempotency: skip if the (target, input, output) pair is already registered.
    const roundsRegistryRead = await hre.viem.getContractAt(
      'RoundsVaultRegistry' as string,
      roundsRegistryAddress as Address,
    )
    const pairId = (await roundsRegistryRead.read.getPairId([fleetAddress])) as `0x${string}`
    const pairAlreadyExists = (await roundsRegistryRead.read.exists([pairId])) as boolean

    if (pairAlreadyExists) {
      console.log(
        kleur.gray(
          `[skip] registerPair(target=${fleetAddress}): pair already exists in RoundsVaultRegistry`,
        ),
      )
    } else {
      // registerPair is gated by RoundsVaultRegistry's Ownable owner — NOT the institution PAM governor —
      // so the batch's `hasGovernorRole` flag does not apply here. Resolve the owner directly.
      const roundsRegistryOwner = (await roundsRegistryRead.read.owner()) as Address
      const deployers = await hre.viem.getWalletClients()
      const deployerThatOwnsRegistry = deployers.find(
        (d) => d.account.address.toLowerCase() === roundsRegistryOwner.toLowerCase(),
      )

      const registerPairAction: GovernorAction = {
        description: `registerPair(${institutionId}, fleet=${fleetAddress})`,
        to: roundsRegistryAddress as Address,
        data: encodeFunctionData({
          abi: ROUNDS_VAULT_REGISTRY_ABI,
          functionName: 'registerPair',
          args: [institutionIdBytes32, fleetAddress, deployedInputVault, deployedOutputVault],
        }),
        value: 0n,
      }

      if (deployerThatOwnsRegistry) {
        const publicClient = await hre.viem.getPublicClient()
        const hash = await deployerThatOwnsRegistry.sendTransaction({
          to: registerPairAction.to,
          data: registerPairAction.data,
          value: registerPairAction.value,
        })
        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`✓ ${registerPairAction.description}`))
      } else {
        console.log(
          kleur
            .yellow()
            .bold(
              `⚠ Pair not registered on RoundsVaultRegistry yet, and no local wallet matches the registry owner.`,
            ),
        )
        console.log(
          kleur.yellow(
            `  RoundsVaultRegistry @ ${roundsRegistryAddress} owner: ${roundsRegistryOwner}`,
          ),
        )
        console.log(
          kleur.yellow(
            `  Local deployers: ${deployers.map((d) => d.account.address).join(', ') || '(none)'}`,
          ),
        )
        console.log(
          kleur.yellow(
            `  Capturing registerPair into the Safe batch — the registry owner must import the JSON to finish wiring.`,
          ),
        )
        batch.enqueue(registerPairAction)
      }
    }
  }

  // Emit Safe Transaction Builder JSON if anything was queued (deployer lacked GOVERNOR_ROLE).
  const publicClient = await hre.viem.getPublicClient()
  const pendingActions = batch.getPending()
  if (pendingActions.length > 0) {
    const chainId = await publicClient.getChainId()
    const outRel = path.join(
      'scripts',
      'output',
      `pending-governor-actions-${network}-${institutionId}-${fleetDefinition.fleetName.replace(/\W/g, '')}.json`,
    )
    const written = await batch.writeSafeBatch(outRel, Number(chainId))
    console.log(
      kleur
        .yellow()
        .bold(
          `${pendingActions.length} governor actions captured for Safe. Import into the Safe UI ` +
            `(Apps → Transaction Builder → Load): ${written}`,
        ),
    )
  } else {
    console.log(kleur.green().bold('All deployment + governor actions executed on-chain.'))
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

  logDeploymentResults(deployedFleet as FleetWhitelistContracts)
  console.log(kleur.green().bold('Whitelisted fleet deployed for institution.'))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
