import hre from 'hardhat'
import ProtocolCore, {ProtocolCoreContracts} from '../ignition/modules/protocol-core'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'
import { Config, BaseConfig } from './config-types'

export function getConfigByNetwork(network: string): BaseConfig {
    const configPath = path.resolve(__dirname, 'config.json')
    if (!fs.existsSync(configPath)) {
        throw new Error(`Config file not found: ${configPath}`)
    }

    const config: Config = JSON.parse(fs.readFileSync(configPath, 'utf8'))

    let _network = network
    if (network === 'hardhat') {
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
    const requiredFields: (keyof BaseConfig)[] = [
        'tokens',
        'treasury',
        'governor',
        'tipJar',
        'swapProvider',
        'aaveV3',
        'compound',
        'morpho',
        'metaMorpho',
        'raft',
        'protocolAccessManager',
        'configurationManager',
        'harborCommand',
        'bufferArk',
        'usdcAaveV3Ark',
        'daiAaveV3Ark',
        'usdcCompoundV3Ark',
        'metamorphoSteakhouseUsdcArk',
        'usdcMorphoArk',
        'daiMorphoArk',
        'tipRate',
    ]

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
    validateAddress(config.treasury, 'treasury')
    validateAddress(config.governor, 'governor')
    validateAddress(config.tipJar, 'tipJar')
    validateAddress(config.swapProvider, 'swapProvider')

    // Validate tip rate
    if (
        isNaN(Number(config.tipRate)) ||
        Number(config.tipRate) < 0 ||
        Number(config.tipRate) > 10000
    ) {
        throw new Error(`Invalid tipRate: ${config.tipRate}. Should be a number between 0 and 10000.`)
    }
}