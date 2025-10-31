import kleur from 'kleur'
import { BaseConfig } from '../../../types/config-types'
import { CrossChainConfig, CrossChainConfigPhase, CrossChainConfigStatus } from '../config/cross-chain'
import { getBridgeRouterAddress, getCrossChainRegistryAddress } from '../config/getters'

/**
 * Validates prerequisites for satellite phase deployment
 */
export function validateSatellitePhasePrerequisites(config: BaseConfig): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Check bridge infrastructure
  if (!config.deployedContracts.bridge) {
    errors.push('Bridge contracts not deployed. Run deploy-xchain-core.ts first.')
  } else {
    if (!getBridgeRouterAddress(config)) {
      errors.push('BridgeRouter not found in config')
    }
    if (!getCrossChainRegistryAddress(config)) {
      errors.push('CrossChainRegistry not found in config')
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Validates prerequisites for hub phase deployment
 */
export function validateHubPhasePrerequisites(config: BaseConfig): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Check bridge infrastructure
  if (!config.deployedContracts.bridge) {
    errors.push('Bridge contracts not deployed. Run deploy-xchain-core.ts first.')
  } else {
    if (!getBridgeRouterAddress(config)) {
      errors.push('BridgeRouter not found in config')
    }
    if (!getCrossChainRegistryAddress(config)) {
      errors.push('CrossChainRegistry not found in config')
    }
  }

  // Check governance contracts
  if (!config.deployedContracts.gov) {
    errors.push('Governance contracts not deployed. Run deploy-gov.ts first.')
  }

  // Check core contracts
  if (!config.deployedContracts.core) {
    errors.push('Core contracts not deployed. Run deploy-core.ts first.')
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Validates prerequisites for registration phase
 */
export function validateRegistrationPrerequisites(
  config: BaseConfig,
  crossChainConfig: CrossChainConfig,
): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Check cross-chain config completeness
  if (!crossChainConfig.sourceChainId || crossChainConfig.sourceChainId === 0) {
    errors.push('Cross-chain config missing sourceChainId')
  }
  if (!crossChainConfig.hubFleetName) {
    errors.push('Cross-chain config missing hubFleetName')
  }

  // Check destinations have all required addresses
  for (const dest of crossChainConfig.destinations) {
    for (const protocol of dest.protocols) {
      if (!protocol.fleetProxyAddress) {
        errors.push(`Missing fleetProxyAddress for destination ${dest.chainId} protocol ${protocol.protocol}`)
      }
      if (!protocol.crossChainArkAddress) {
        errors.push(`Missing crossChainArkAddress for destination ${dest.chainId} protocol ${protocol.protocol}`)
      }
      if (!protocol.satelliteFleetAddress) {
        errors.push(`Missing satelliteFleetAddress for destination ${dest.chainId} protocol ${protocol.protocol}`)
      }
    }
  }

  // Check bridge infrastructure
  if (!config.deployedContracts.bridge) {
    errors.push('Bridge contracts not deployed. Run deploy-xchain-core.ts first.')
  } else {
    if (!getBridgeRouterAddress(config)) {
      errors.push('BridgeRouter not found in config')
    }
    if (!getCrossChainRegistryAddress(config)) {
      errors.push('CrossChainRegistry not found in config')
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Prints validation errors in a user-friendly format
 */
export function printValidationErrors(errors: string[], phase: CrossChainConfigPhase): void {
  console.log(kleur.red().bold(`❌ Validation failed for ${phase} phase:`))
  errors.forEach((error) => {
    console.log(kleur.red(`  • ${error}`))
  })
  console.log()
}

/**
 * Prints validation success message
 */
export function printValidationSuccess(phase: CrossChainConfigPhase): void {
  console.log(kleur.green().bold(`✅ Prerequisites validated for ${phase} phase`))
  console.log()
}

/**
 * Gets deployment phase guidance based on config status
 */
export function getDeploymentGuidance(status: CrossChainConfigStatus): string[] {
  const guidance: string[] = []

  switch (status.phase) {
    case 'satellite':
      guidance.push('Next steps:')
      guidance.push('1. Deploy FleetProxy on satellite chain: npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network <satellite>')
      guidance.push('2. Deploy hub fleet and CrossChainArk on source chain')
      guidance.push('3. Register adapter peer relationships on both chains')
      break

    case 'hub':
      guidance.push('Next steps:')
      guidance.push('1. Deploy CrossChainArk on source chain: npx hardhat run scripts/arks/deploy-xchain-ark.ts --network <source>')
      guidance.push('2. Register adapter peer relationships on both chains')
      break

    case 'complete':
      guidance.push('Cross-chain setup is complete!')
      guidance.push('Next steps:')
      guidance.push('1. Register adapter peers: npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network <chain>')
      guidance.push('2. Verify setup: npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network <chain>')
      break
  }

  if (status.missingFields.length > 0) {
    guidance.push('')
    guidance.push('Missing components:')
    status.missingFields.forEach((field) => {
      guidance.push(`  • ${field}`)
    })
  }

  return guidance
}

/**
 * Validates that a fleet deployment exists for the given fleet name
 */
export function validateFleetDeploymentExists(fleetName: string): { exists: boolean; path?: string } {
  const fs = require('fs')
  const path = require('path')
  
  const deploymentsDir = path.resolve(process.cwd(), 'deployments', 'fleets')
  const deploymentFiles = fs.readdirSync(deploymentsDir).filter((file: string) => file.endsWith('_deployment.json'))
  
  for (const file of deploymentFiles) {
    const deploymentPath = path.join(deploymentsDir, file)
    const deploymentContent = fs.readFileSync(deploymentPath, 'utf8')
    const fleetDeployment = JSON.parse(deploymentContent)
    
    if (fleetDeployment.fleetName === fleetName) {
      return { exists: true, path: deploymentPath }
    }
  }
  
  return { exists: false }
}
