import { Address, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { Raft } from '../../generated/Raft/Raft'
import { AaveV2Oracle } from '../../generated/templates/FleetCommanderTemplate/AaveV2Oracle'
import { AaveV3Oracle } from '../../generated/templates/FleetCommanderTemplate/AaveV3Oracle'
import { EnsRegistry } from '../../generated/templates/FleetCommanderTemplate/EnsRegistry'
import { EnsReverseResolver } from '../../generated/templates/FleetCommanderTemplate/EnsReverseResolver'
import { FeedRegistry } from '../../generated/templates/FleetCommanderTemplate/FeedRegistry'
import { OneInchOracle } from '../../generated/templates/FleetCommanderTemplate/OneInchOracle'
import { SdaiOracle } from '../../generated/templates/FleetCommanderTemplate/SdaiOracle'
import { SparkOracle } from '../../generated/templates/FleetCommanderTemplate/SparkOracle'
import { SusdeOracle } from '../../generated/templates/FleetCommanderTemplate/SusdeOracle'

export class ServiceAddresses {
  WSTETH: Address
  STETH: Address
  WETH: Address
  WBTC: Address
  USDC: Address
  USDCE: Address
  USDT: Address
  SDAI: Address
  DAI: Address
  FEED_REGISTRY: Address
  USD: Address
  ETH: Address
  BTC: Address
  ONE_INCH_ORACLE_1: Address
  ONE_INCH_ORACLE_2: Address
  ONE_INCH_ORACLE_3: Address
  ONE_INCH_ORACLE_4: Address
  AAVE_ORACLE: Address
  SDAI_ORACLE: Address
  CDP_MANAGER: Address
  ZERO_ADDRESS: Address
  SUSDE: Address
  SUSDE_ORACLE: Address
  AAVE_V2_ORACLE: Address
  AAVE_V3_ORACLE: Address
  SPARK_ORACLE: Address
  ENS_REVERSE_REGISTRY: Address
  ENS_REGISTRY: Address
  RAFT: Address
}

export class Services {
  feedRegistry: FeedRegistry
  aaveV3Oracle: AaveV3Oracle
  sparkOracle: SparkOracle
  oneInchOracle1: OneInchOracle
  oneInchOracle2: OneInchOracle
  oneInchOracle3: OneInchOracle
  oneInchOracle4: OneInchOracle
  aaveV2Oracle: AaveV2Oracle
  sDaiOracle: SdaiOracle
  susdeOracle: SusdeOracle
  ensReverseRegistry: EnsReverseResolver
  ensRegistry: EnsRegistry
  raft: Raft
}

export function getAddressesProvider(): ServiceAddresses {
  const network = dataSource.network()

  if (network == 'mainnet') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0'),
      STETH: Address.fromString('0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84'),
      WETH: Address.fromString('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'),
      WBTC: Address.fromString('0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'),
      USDC: Address.fromString('0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'),
      USDCE: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x6B175474E89094C44Da98b954EedeAC495271d0F'),
      SDAI: Address.fromString('0x83F20F44975D03b1b09e64809B757c47f942BEeA'),
      AAVE_V2_ORACLE: Address.fromString('0xA50ba011c48153De246E5192C8f9258A2ba79Ca9'),
      FEED_REGISTRY: Address.fromString('0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf'),
      AAVE_V3_ORACLE: Address.fromString('0x54586bE62E3c3580375aE3723C145253060Ca0C2'),
      SPARK_ORACLE: Address.fromString('0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
      ONE_INCH_ORACLE_1: Address.fromString('0x07D91f5fb9Bf7798734C3f606dB065549F6893bb'),
      ONE_INCH_ORACLE_2: Address.fromString('0x3E1Fe1Bd5a5560972bFa2D393b9aC18aF279fF56'),
      ONE_INCH_ORACLE_3: Address.fromString('0x52cbE0f49CcdD4Dc6E9C13BAb024EABD2842045B'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      AAVE_ORACLE: Address.fromString('0x54586bE62E3c3580375aE3723C145253060Ca0C2'),
      SDAI_ORACLE: Address.fromString('0xb9E6DBFa4De19CCed908BcbFe1d015190678AB5f'),
      CDP_MANAGER: Address.fromString('0x5ef30b9986345249bc32d8928b7ee64de9435e39'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x9d39a5de30e57443bff2a8307a4256c8797a3497'),
      SUSDE_ORACLE: Address.fromString('0x5D916980D5Ae1737a8330Bf24dF812b2911Aae25'),
      USDT: Address.fromString('0xdac17f958d2ee523a2206206994597c13d831ec7'),
      ENS_REVERSE_REGISTRY: Address.fromString('0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb'),
      ENS_REGISTRY: Address.fromString('0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e'),
      RAFT: Address.fromString('0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E'),
    }
    return addresses
  } else if (network == 'optimism') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x4200000000000000000000000000000000000006'),
      WBTC: Address.fromString('0x68f180fcce6836688e9084f035309e29bf0a2095'),
      USDC: Address.fromString('0x7F5c764cBc14f9669B88837ca1490cCa17c31607'),
      USDCE: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V2_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_ORACLE: Address.fromString('0xD81eb3728a631871a7eBBaD631b5f424909f0c77'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
      ONE_INCH_ORACLE_1: Address.fromString('0x11DEE30E710B8d4a8630392781Cc3c0046365d4c'),
      ONE_INCH_ORACLE_2: Address.fromString('0x59Bc892E1832aE86C268fC21a91fE940830a52b0'),
      ONE_INCH_ORACLE_3: Address.fromString('0x52cbE0f49CcdD4Dc6E9C13BAb024EABD2842045B'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      AAVE_ORACLE: Address.fromString('0xD81eb3728a631871a7eBBaD631b5f424909f0c77'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      CDP_MANAGER: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0x94b008aa00579c1307b0ef2c499ad98a8ce58e58'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      RAFT: Address.fromString('0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E'),
    }
    return addresses
  } else if (network == 'base') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x4200000000000000000000000000000000000006'),
      WBTC: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDC: Address.fromString('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
      USDCE: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V2_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_ORACLE: Address.fromString('0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
      ONE_INCH_ORACLE_1: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      ONE_INCH_ORACLE_2: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_3: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_ORACLE: Address.fromString('0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      CDP_MANAGER: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      RAFT: Address.fromString('0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E'),
    }
    return addresses
  } else if (network == 'arbitrum-one') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x82af49447d8a07e3bd95bd0d56f35241523fbab1'),
      WBTC: Address.fromString('0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f'),
      USDC: Address.fromString('0xaf88d065e77c8cC2239327C5EDb3A432268e5831'),
      USDCE: Address.fromString('0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V2_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_ORACLE: Address.fromString('0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
      ONE_INCH_ORACLE_1: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      ONE_INCH_ORACLE_2: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_3: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_ORACLE: Address.fromString('0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      CDP_MANAGER: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      RAFT: Address.fromString('0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E'),
    }
    return addresses
  }

  throw new Error(`Unsupported network: ${network}`)
}
export const addresses = getAddressesProvider()

export function getServicesProvider(): Services {
  const addresses = getAddressesProvider()

  const services: Services = {
    feedRegistry: FeedRegistry.bind(addresses.FEED_REGISTRY),
    oneInchOracle1: OneInchOracle.bind(addresses.ONE_INCH_ORACLE_1),
    oneInchOracle2: OneInchOracle.bind(addresses.ONE_INCH_ORACLE_2),
    oneInchOracle3: OneInchOracle.bind(addresses.ONE_INCH_ORACLE_3),
    oneInchOracle4: OneInchOracle.bind(addresses.ONE_INCH_ORACLE_4),
    aaveV3Oracle: AaveV3Oracle.bind(addresses.AAVE_ORACLE),
    sDaiOracle: SdaiOracle.bind(addresses.SDAI_ORACLE),
    susdeOracle: SusdeOracle.bind(addresses.SUSDE_ORACLE),
    aaveV2Oracle: AaveV2Oracle.bind(addresses.AAVE_V3_ORACLE),
    sparkOracle: SparkOracle.bind(addresses.SPARK_ORACLE),
    ensReverseRegistry: EnsReverseResolver.bind(addresses.ENS_REVERSE_REGISTRY),
    ensRegistry: EnsRegistry.bind(addresses.ENS_REGISTRY),
    raft: Raft.bind(addresses.RAFT),
  }
  return services
}
export const services = getServicesProvider()

/**
 * @dev https://github.com/1inch/spot-price-aggregator
 * */
export function getOneInchOracle(blockNumber: BigInt): OneInchOracle | null {
  const network = dataSource.network()
  if (network == 'mainnet') {
    if (blockNumber.toI32() > 18040583) {
      return services.oneInchOracle4
    } else if (blockNumber.toI32() > 17684577) {
      return services.oneInchOracle3
    } else if (blockNumber.toI32() > 16995101) {
      return services.oneInchOracle2
    } else if (blockNumber.toI32() > 12522266) {
      return services.oneInchOracle1
    }
  }
  if (network == 'optimism') {
    if (blockNumber.toI32() > 108982420) {
      return services.oneInchOracle4
    } else if (blockNumber.toI32() > 106824951) {
      return services.oneInchOracle3
    } else if (blockNumber.toI32() > 86897611) {
      return services.oneInchOracle2
    } else if (blockNumber.toI32() > 0) {
      return services.oneInchOracle1
    }
  }
  if (network == 'base') {
    return services.oneInchOracle1
  }
  if (network == 'arbitrum-one') {
    return services.oneInchOracle1
  }
  return null
}
