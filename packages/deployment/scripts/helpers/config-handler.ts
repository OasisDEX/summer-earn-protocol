import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { BaseConfig, Config } from '../../types/config-types'

export function getConfigByNetwork(network: string): BaseConfig {
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
  validateConfig(networkConfig)

  return networkConfig
}

function validateConfig(config: BaseConfig): void {
  const requiredFields: (keyof BaseConfig)[] = ['tokens', 'deployedContracts', 'protocolSpecific']

  for (const field of requiredFields) {
    if (!(field in config)) {
      throw new Error(`Missing required field in config: ${field}`)
    }
  }

  // Validate that all address fields are non-empty strings
  const validateAddress = (address: string, fieldName: string) => {
    if (typeof address !== 'string' || !address.startsWith('0x')) {
      throw new Error(`Invalid address for ${fieldName}: ${address}`)
    }
  }
  for (const token in config.tokens) {
    validateAddress(config.tokens[token as keyof typeof config.tokens], `tokens.${token}`)
  }
  validateAddress(config.deployedContracts.gov.summerToken.address, 'core.governor')
  validateAddress(config.deployedContracts.core.tipJar.address, 'core.tipJar')
  validateAddress(config.deployedContracts.core.raft.address, 'core.raft')
  validateAddress(
    config.deployedContracts.gov.protocolAccessManager.address,
    'gov.protocolAccessManager',
  )
  validateAddress(
    config.deployedContracts.core.configurationManager.address,
    'core.configurationManager',
  )
  validateAddress(config.deployedContracts.core.harborCommand.address, 'core.harborCommand')

  // Validate tip rate
  if (
    isNaN(Number(config.common.tipRate)) ||
    Number(config.common.tipRate) < 0 ||
    Number(config.common.tipRate) > 10000
  ) {
    throw new Error(
      `Invalid tipRate: ${config.common.tipRate}. Should be a number between 0 and 10000.`,
    )
  }
}
