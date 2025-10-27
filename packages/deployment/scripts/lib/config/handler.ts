import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { CoreContracts } from '../../ignition/modules/core'
import { GovContracts } from '../../ignition/modules/gov'
import { BaseConfig, Config } from '../../types/config-types'
import { readInstitutionConfigFile } from './institution-config'
import { validateAddress, validateNumber } from './validation'

type ValidateConfig = {
  common?: boolean
  gov?: boolean
  core?: boolean
  bridge?: boolean
}

/**
 * Gets the configuration for a specific network or all networks
 * @param network The network name or 'all' for all networks
 * @param validateConfig Configuration validation options
 * @param useBummerConfig Whether to use the test/bummer configuration
 * @returns The network configuration(s)
 */
export function getConfigByNetwork(
  network: string,
  validateConfig: ValidateConfig,
  useBummerConfig: boolean = false,
): BaseConfig | Config {
  // Determine which config file to use
  const configFileName = useBummerConfig ? 'index.test.json' : 'index.json'
  const configPath = path.resolve(__dirname, '..', '..', 'config', configFileName)

  if (!fs.existsSync(configPath)) {
    throw new Error(`Config file not found: ${configPath}`)
  }

  if (useBummerConfig) {
    console.log(kleur.yellow().bold(`\nUsing bummer config from ${configFileName}!`))
  }

  const config: Config = JSON.parse(fs.readFileSync(configPath, 'utf8'))

  // Return all network configs if 'all' is requested
  if (network === 'all') {
    return config
  }

  let _network = network
  if (network === 'hardhat' || network === 'local') {
    console.log(kleur.red().bold('\nUsing base config for local/hardhat network!'))
    _network = 'base'
  }

  if (!(_network in config)) {
    throw new Error(`Network configuration not found for: ${_network}`)
  }

  const networkConfig = config[_network as keyof Config]
  if (validateConfig.common) {
    validateCommonConfig(networkConfig)
  }
  // if (validateConfig.gov) {
  //   validateGovDeployment(networkConfig)
  // }
  if (validateConfig.core) {
    validateCoreDeployment(networkConfig)
  }
  if (validateConfig.bridge) {
    validateBridgeDeployment(networkConfig)
  }
  return networkConfig
}

/**
 * Loads the base network config and overlays institution-scoped deployedContracts
 * from packages/deployment/config/institutions/<institutionId>/index(.test).json
 * Only the deployedContracts.gov and deployedContracts.core sections are overridden.
 */
export function getInstitutionConfigByNetwork(
  network: string,
  institutionId: string,
  validateConfig: ValidateConfig,
  useBummerConfig: boolean = false,
): BaseConfig {
  const baseConfig = getConfigByNetwork(network, validateConfig, useBummerConfig)

  // Clone to avoid mutating the cached/base object
  const mergedConfig: BaseConfig = JSON.parse(JSON.stringify(baseConfig))

  const index = readInstitutionConfigFile(institutionId, useBummerConfig)

  // Normalize local network mapping consistent with getConfigByNetwork
  const _network = network === 'hardhat' || network === 'local' ? 'base' : network
  const institutionNet = (index as any)[_network] as any
  const deployed = institutionNet?.deployedContracts as any

  if (deployed?.gov) {
    for (const k of Object.keys(deployed.gov)) {
      const addressObj = deployed.gov[k]
      if (addressObj?.address) {
        ;(mergedConfig.deployedContracts.gov as any)[k] = { address: addressObj.address }
      }
    }
  }

  if (deployed?.core) {
    for (const k of Object.keys(deployed.core)) {
      const addressObj = deployed.core[k]
      if (addressObj?.address) {
        ;(mergedConfig.deployedContracts.core as any)[k] = { address: addressObj.address }
      }
    }
  }

  // Optionally re-run validations after merge
  if (validateConfig.core) {
    validateCoreDeployment(mergedConfig)
  }
  // if (validateConfig.gov) validateGovDeployment(mergedConfig)

  return mergedConfig
}

export function validateCommonConfig(config: BaseConfig): void {
  const requiredFields: (keyof BaseConfig)[] = ['tokens', 'deployedContracts', 'protocolSpecific']

  for (const field of requiredFields) {
    if (!(field in config)) {
      throw new Error(`Missing required field in config: ${field}`)
    }
  }

  // for (const token in config.tokens) {
  //   validateAddress(config.tokens[token as keyof typeof config.tokens], `tokens.${token}`)
  // }

  validateAddress(config.common.swapProvider, 'swapProvider')
  validateAddress(config.common.layerZero.lzEndpoint, 'layerZero.lzEndpoint')
  validateNumber(+config.common.layerZero.eID, 'layerZero.eID', 0, 1000000)
  validateNumber(+config.common.tipRate, 'tipRate', 0, 10000)
}

export const validateGovDeployment = (config: BaseConfig) => {
  for (const contract in config.deployedContracts.gov) {
    validateAddress(
      config.deployedContracts.gov[contract as keyof GovContracts].address,
      `gov.${contract}`,
    )
  }
}

export const validateCoreDeployment = (config: BaseConfig) => {
  for (const contract in config.deployedContracts.core) {
    validateAddress(
      config.deployedContracts.core[contract as keyof CoreContracts].address,
      `core.${contract}`,
    )
  }
}

export const validateBridgeDeployment = (config: BaseConfig) => {
  if (!config.deployedContracts.bridge) {
    throw new Error('Missing bridge deployment configuration')
  }

  validateAddress(config.deployedContracts.bridge.bridgeRouter.address, 'bridge.bridgeRouter')
  validateAddress(config.deployedContracts.bridge.bridgeQueue.address, 'bridge.bridgeQueue')
}
