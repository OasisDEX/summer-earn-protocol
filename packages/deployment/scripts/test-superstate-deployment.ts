import hre from 'hardhat'
import { deploySuperstateArk } from './arks/deploy-superstate-ark'
import { getConfigByNetwork } from './helpers/config-handler'
import { BaseConfig } from '../types/config-types'

async function main() {
  console.log('Testing SuperstateArk deployment on local network...')
  const config = getConfigByNetwork(
    'mainnet',
    { common: true, gov: true, core: true },
    true,
  ) as BaseConfig

  const superstateTokenConfig = config.protocolSpecific.superstate?.usdc?.USTB

  if (!superstateTokenConfig) {
    throw new Error('Superstate config not found')
  }

  const { ark } = await deploySuperstateArk(config, {
    token: { address: config.tokens.usdc, symbol: 'usdc' as any },
    depositCap: '1000000000000000000000',
    maxRebalanceOutflow: '0',
    maxRebalanceInflow: '0',
    maxDepositPercentageOfTVL: '0',
    fleetName: 'TestFleet',
    version: 1,
    variant: superstateTokenConfig.variant,
    shareToken: superstateTokenConfig.shareToken,
    superstateSubscribe: superstateTokenConfig.superstateSubscribe,
    superstateRedeem: superstateTokenConfig.superstateRedeem,
    oracle: superstateTokenConfig.oracle,
    fundName: 'USTB',
    sweepSlippage: superstateTokenConfig.sweepSlippage,
    depositSlippage: superstateTokenConfig.depositSlippage,
  })

  console.log(`Successfully deployed to: ${ark.address}`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
