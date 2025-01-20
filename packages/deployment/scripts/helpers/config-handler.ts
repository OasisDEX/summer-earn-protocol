import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { CoreContracts } from '../../ignition/modules/core'
import { GovContracts } from '../../ignition/modules/gov'
import { BaseConfig, Config } from '../../types/config-types'
import { validateAddress, validateNumber } from './validation'

type ValidateConfig = {
  common: boolean
  gov: boolean
  core: boolean
}

export function getConfigByNetwork(network: string, validateConfig: ValidateConfig): BaseConfig {
  const configPath = path.resolve(__dirname, '..', '..', 'config', 'index.json')
  if (!fs.existsSync(configPath)) {
    throw new Error(`Config file not found: ${configPath}`)
  }

  const config: Config = JSON.parse(fs.readFileSync(configPath, 'utf8'))

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
  if (validateConfig.gov) {
    validateGovDeployment(networkConfig)
  }
  if (validateConfig.core) {
    validateCoreDeployment(networkConfig)
  }
  return networkConfig
}

export function validateCommonConfig(config: BaseConfig): void {
  const requiredFields: (keyof BaseConfig)[] = ['tokens', 'deployedContracts', 'protocolSpecific']

  for (const field of requiredFields) {
    if (!(field in config)) {
      throw new Error(`Missing required field in config: ${field}`)
    }
  }

  for (const token in config.tokens) {
    validateAddress(config.tokens[token as keyof typeof config.tokens], `tokens.${token}`)
  }

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
