import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, Address as ViemAddress } from 'viem'
import { FleetConfig } from '../types/config-types'
import { saveFleetDeploymentJson } from './common/fleet-deployment-files-helpers'
import { deployFleetContracts, logDeploymentResults } from './fleets/fleet-contracts'
import {
  deployArks,
  getRewardsManagerAddress,
  setupFleetRewards,
} from './fleets/fleet-deployment-helpers'
import { getConfigByNetwork } from './helpers/config-handler'
import {
  getInstitutionFleetConfigDir,
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
  return { ...parsed, details: JSON.stringify(parsed.details) } as unknown as FleetConfig
}

async function main() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const { institutionId } = await prompts({
    type: 'text',
    name: 'institutionId',
    message: 'Enter institution id (folder name under config/institutions):',
    validate: (v) => (v && /^[A-Za-z0-9_-]+$/.test(v) ? true : 'Invalid id'),
  })
  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  const config = getConfigByNetwork(network, { gov: true, core: true }, useBummerConfig)

  const fleetDefinition = await selectInstitutionFleetConfig(institutionId, useBummerConfig)
  validateToken(config, fleetDefinition.assetSymbol)

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

  const deployedFleet = await deployFleetContracts(fleetDefinition, config, assetAddress)
  const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()
  const deployedArks = await deployArks(fleetDefinition, config)

  saveFleetDeploymentJson(
    fleetDefinition,
    deployedFleet,
    bufferArkAddress as Address,
    deployedArks,
    useBummerConfig,
  )

  // Persist institution-scoped fleet entry using the fleet config filename (requested: same name as config)
  const fleetNameKey = fleetDefinition.fleetName
  updateInstitutionFleetEntry(institutionId, useBummerConfig, network, fleetNameKey, {
    fleetCommander: deployedFleet.fleetCommander.address as ViemAddress,
    bufferArk: bufferArkAddress as ViemAddress,
    arks: deployedArks as ViemAddress[],
  })

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
