import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { BaseConfig, Config } from '../../ignition/config/config-types'

export function getConfigByNetwork(network: string): BaseConfig {
  const configPath = path.resolve(__dirname, '../../ignition/config/index.json')
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
  const requiredFields: (keyof BaseConfig)[] = ['tokens', 'core', 'aaveV3', 'morpho']

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

  validateAddress(config.tokens.usdc, 'tokens.usdc')
  validateAddress(config.tokens.dai, 'tokens.dai')
  validateAddress(config.core.treasury, 'core.treasury')
  validateAddress(config.core.governor, 'core.governor')
  validateAddress(config.core.tipJar, 'core.tipJar')
  validateAddress(config.core.raft, 'core.raft')
  validateAddress(config.core.protocolAccessManager, 'core.protocolAccessManager')
  validateAddress(config.core.configurationManager, 'core.configurationManager')
  validateAddress(config.core.harborCommand, 'core.harborCommand')

  // Validate tip rate
  if (
    isNaN(Number(config.core.tipRate)) ||
    Number(config.core.tipRate) < 0 ||
    Number(config.core.tipRate) > 10000
  ) {
    throw new Error(
      `Invalid tipRate: ${config.core.tipRate}. Should be a number between 0 and 10000.`,
    )
  }
}
