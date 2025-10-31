import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { BaseConfig } from '../../../types/config-types'
import {
  getCrossChainConfigStatus,
  loadCrossChainConfig,
  mergeCrossChainConfig,
  saveCrossChainConfig,
  validateCrossChainConfigPhase,
} from '../../lib/config/cross-chain'
import { getAllDestinationChainIds } from '../../lib/config/cross-chain-getters'
import { getConfigByNetwork } from '../../lib/config/handler'
import {
  printValidationErrors,
  printValidationSuccess,
  validateSatellitePhasePrerequisites,
} from '../../lib/cross-chain/validation'
import { promptForConfigType } from '../../lib/infrastructure/prompts'

function listCrossChainConfigs(): string[] {
  const fs = require('fs')
  const dir = path.join(process.cwd(), 'config', 'cross-chain')
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((f: string) => f.endsWith('.json'))
    .sort()
}

async function chooseFleetConfig(): Promise<string | null> {
  const files = listCrossChainConfigs()
  if (files.length === 0) {
    console.log(kleur.yellow('No cross-chain config files found under config/cross-chain'))
    return null
  }

  const { selected } = await prompts({
    type: 'select',
    name: 'selected',
    message: 'Select a fleet cross-chain config to add destination to:',
    choices: files.map((f) => ({ title: f, value: f })),
  })
  return selected || null
}

export async function addCrossChainDestination() {
  console.log(kleur.green().bold('Adding new destination to existing cross-chain fleet...'))
  console.log(
    kleur.yellow('This script helps add a new satellite chain to an existing cross-chain fleet.'),
  )

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      core: true,
      bridge: true,
    },
    useBummerConfig,
  ) as BaseConfig

  // Validate prerequisites
  const validation = validateSatellitePhasePrerequisites(config)
  if (!validation.isValid) {
    printValidationErrors(validation.errors, 'satellite')
    throw new Error('Prerequisites not met for satellite phase deployment')
  }
  printValidationSuccess('satellite')

  const chosen = await chooseFleetConfig()
  if (!chosen) return

  const fleetName = chosen.replace(/\.json$/, '')
  const existingConfig = loadCrossChainConfig(fleetName)
  if (!existingConfig) {
    throw new Error(`Failed to load cross-chain config for ${fleetName}`)
  }

  // Check if config is in a valid state to add destinations
  const satelliteValidation = validateCrossChainConfigPhase(existingConfig, 'satellite')
  if (!satelliteValidation.isValid) {
    console.log(kleur.red('Cross-chain config is not in valid satellite phase.'))
    console.log(kleur.red('Please complete the initial satellite deployment first.'))
    return
  }

  console.log(kleur.blue(`Current config status:`))
  const status = getCrossChainConfigStatus(fleetName)
  console.log(kleur.blue(`Phase: ${status.phase}`))
  console.log(kleur.blue(`Existing destinations: ${existingConfig.destinations.length}`))

  // Get new destination details
  const { chainId } = await prompts({
    type: 'number',
    name: 'chainId',
    message: 'Enter the chain ID for the new destination:',
    validate: (value: number) => {
      if (!value || value <= 0) return 'Chain ID must be a positive number'
      // Check if chain ID already exists
      if (getAllDestinationChainIds(existingConfig).includes(value)) {
        return 'Chain ID already exists in this config'
      }
      return true
    },
  })

  const { chainName } = await prompts({
    type: 'text',
    name: 'chainName',
    message: 'Enter a name for this chain (e.g., "base", "arbitrum"):',
    validate: (value: string) => (value.length > 0 ? true : 'Chain name is required'),
  })

  const { fleetProxyAddress } = await prompts({
    type: 'text',
    name: 'fleetProxyAddress',
    message: 'Enter the FleetProxy address for this destination:',
    validate: (value: string) => {
      if (!value || value.trim() === '') return 'FleetProxy address is required'
      if (!value.startsWith('0x') || value.length !== 42) {
        return 'Please enter a valid Ethereum address (0x...)'
      }
      return true
    },
  })

  const { satelliteFleetAddress } = await prompts({
    type: 'text',
    name: 'satelliteFleetAddress',
    message: 'Enter the satellite fleet address for this destination:',
    validate: (value: string) => {
      if (!value || value.trim() === '') return 'Satellite fleet address is required'
      if (!value.startsWith('0x') || value.length !== 42) {
        return 'Please enter a valid Ethereum address (0x...)'
      }
      return true
    },
  })

  const { protocol } = await prompts({
    type: 'text',
    name: 'protocol',
    message: 'Enter the protocol name (default: summerfi):',
    initial: 'summerfi',
    validate: (value: string) => (value.length > 0 ? true : 'Protocol name is required'),
  })

  // Confirm the addition
  console.log(kleur.yellow('\nNew destination details:'))
  console.log(kleur.blue(`Chain ID: ${chainId}`))
  console.log(kleur.blue(`Chain Name: ${chainName}`))
  console.log(kleur.blue(`FleetProxy: ${fleetProxyAddress}`))
  console.log(kleur.blue(`Satellite Fleet: ${satelliteFleetAddress}`))
  console.log(kleur.blue(`Protocol: ${protocol}`))

  const { confirm } = await prompts({
    type: 'confirm',
    name: 'confirm',
    message: 'Add this destination to the cross-chain config?',
    initial: true,
  })

  if (!confirm) {
    console.log(kleur.red('Operation cancelled.'))
    return
  }

  // Add the new destination
  const updatedConfig = mergeCrossChainConfig(existingConfig, {
    destinations: [
      ...existingConfig.destinations,
      {
        chainId,
        name: chainName,
        protocols: [
          {
            protocol,
            fleetProxyAddress: fleetProxyAddress.trim(),
            crossChainArkAddress: '', // Will be set when CrossChainArk is deployed
            satelliteFleetAddress: satelliteFleetAddress.trim(),
            assetAddress: '', // Will be set when FleetProxy is deployed
            assetSymbol: '', // Will be set when FleetProxy is deployed
          },
        ],
      },
    ],
  })

  saveCrossChainConfig(fleetName, updatedConfig)
  console.log(kleur.green('✓ Added new destination to cross-chain configuration'))

  // Show updated status
  const newStatus = getCrossChainConfigStatus(fleetName)
  console.log(kleur.blue(`Updated phase: ${newStatus.phase}`))
  console.log(kleur.blue(`Total destinations: ${updatedConfig.destinations.length}`))

  console.log(kleur.green().bold('\n✅ Destination added successfully!'))
  console.log(kleur.yellow('Next steps:'))
  console.log(kleur.cyan('1. Deploy CrossChainArk on the source chain (if not already done)'))
  console.log(
    kleur.cyan(
      '2. Register adapter peers: npx hardhat run scripts/bridge/post-deployment/register-ark-fleet.ts --network <chain>',
    ),
  )
  console.log(
    kleur.cyan(
      '3. Verify setup: npx hardhat run scripts/bridge/post-deployment/verify-setup.ts --network <chain>',
    ),
  )
}

if (require.main === module) {
  addCrossChainDestination().catch((error) => {
    console.error(kleur.red('Error adding cross-chain destination:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

