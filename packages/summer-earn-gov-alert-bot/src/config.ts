import { mainnet, base, arbitrum, sonic } from 'viem/chains'
import { SupportedNetworks } from './services/validation'
import validatorConfig from './config/index.json'

export const viemChains = {
  [SupportedNetworks.MAINNET]: mainnet,
  [SupportedNetworks.BASE]: base,
  [SupportedNetworks.ARBITRUM]: arbitrum,
  [SupportedNetworks.SONIC]: sonic,
}

export const getNetworkConfig = (network: SupportedNetworks) => {
  return (validatorConfig as any)[network]
}

export const getGovernorAddresses = (network: SupportedNetworks): `0x${string}`[] => {
  const cfg = getNetworkConfig(network)
  const addresses: `0x${string}`[] = []

  if (cfg.deployedContracts?.gov?.summerGovernor?.address) {
    addresses.push(cfg.deployedContracts.gov.summerGovernor.address.toLowerCase() as `0x${string}`)
  }
  if (cfg.deployedContracts?.govV2?.summerGovernor?.address) {
    addresses.push(
      cfg.deployedContracts.govV2.summerGovernor.address.toLowerCase() as `0x${string}`,
    )
  }

  return addresses
}

export const getTimelockAddress = (network: SupportedNetworks): `0x${string}` | undefined => {
  const cfg = getNetworkConfig(network)
  return cfg.deployedContracts?.gov?.timelock?.address as `0x${string}`
}
