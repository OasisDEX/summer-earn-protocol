import { Address, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { AaveV3Oracle } from '../../generated/EntryPoint/AaveV3Oracle'
import { FeedRegistry } from '../../generated/EntryPoint/FeedRegistry'
import { OneInchOracle } from '../../generated/EntryPoint/OneInchOracle'
import { SparkOracle } from '../../generated/EntryPoint/SparkOracle'

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
  EURC: Address
  USD: Address
  ETH: Address
  BTC: Address
  FEED_REGISTRY: Address
  ONE_INCH_ORACLE_1: Address
  ONE_INCH_ORACLE_2: Address
  ONE_INCH_ORACLE_3: Address
  ONE_INCH_ORACLE_4: Address
  AAVE_ORACLE: Address
  SDAI_ORACLE: Address
  ZERO_ADDRESS: Address
  SUSDE: Address
  SUSDE_ORACLE: Address
  AAVE_LENDING_POOL: Address
  AAVE_DATA_PROVIDER: Address
  AAVE_PRICE_ORACLE: Address
  AAVE_V3_LENDING_POOL: Address
  AAVE_V3_DATA_PROVIDER: Address
  AAVE_V3_ORACLE: Address
  SPARK_ORACLE: Address
  SPARK_DATA_PROVIDER: Address
  SPARK_LENDING_POOL: Address
  MORPHO: Address
  ENS_REVERSE_REGISTRY: Address
  ENS_REGISTRY: Address
  PENDLE_ORACLE: Address
  SKY_USDS_PSM3: Address
  SUSDS: Address
}

export class Services {
  feedRegistry: FeedRegistry
  aaveV3Oracle: AaveV3Oracle
  sparkOracle: SparkOracle
  oneInchOracle1: OneInchOracle
  oneInchOracle2: OneInchOracle
  oneInchOracle3: OneInchOracle
  oneInchOracle4: OneInchOracle
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
      EURC: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x6B175474E89094C44Da98b954EedeAC495271d0F'),
      SDAI: Address.fromString('0x83F20F44975D03b1b09e64809B757c47f942BEeA'),
      AAVE_LENDING_POOL: Address.fromString('0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9'),
      AAVE_DATA_PROVIDER: Address.fromString('0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3'),
      AAVE_PRICE_ORACLE: Address.fromString('0xA50ba011c48153De246E5192C8f9258A2ba79Ca9'),
      FEED_REGISTRY: Address.fromString('0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf'),
      AAVE_V3_LENDING_POOL: Address.fromString('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2'),
      AAVE_V3_DATA_PROVIDER: Address.fromString('0x41393e5e337606dc3821075Af65AeE84D7688CBD'),
      AAVE_V3_ORACLE: Address.fromString('0x54586bE62E3c3580375aE3723C145253060Ca0C2'),
      SPARK_ORACLE: Address.fromString('0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9'),
      SPARK_DATA_PROVIDER: Address.fromString('0xFc21d6d146E6086B8359705C8b28512a983db0cb'),
      SPARK_LENDING_POOL: Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
      ONE_INCH_ORACLE_1: Address.fromString('0x07D91f5fb9Bf7798734C3f606dB065549F6893bb'),
      ONE_INCH_ORACLE_2: Address.fromString('0x3E1Fe1Bd5a5560972bFa2D393b9aC18aF279fF56'),
      ONE_INCH_ORACLE_3: Address.fromString('0x52cbE0f49CcdD4Dc6E9C13BAb024EABD2842045B'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      AAVE_ORACLE: Address.fromString('0x54586bE62E3c3580375aE3723C145253060Ca0C2'),
      SDAI_ORACLE: Address.fromString('0xb9E6DBFa4De19CCed908BcbFe1d015190678AB5f'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x9d39a5de30e57443bff2a8307a4256c8797a3497'),
      SUSDE_ORACLE: Address.fromString('0x5D916980D5Ae1737a8330Bf24dF812b2911Aae25'),
      USDT: Address.fromString('0xdac17f958d2ee523a2206206994597c13d831ec7'),
      MORPHO: Address.fromString('0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb'),
      ENS_REVERSE_REGISTRY: Address.fromString('0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb'),
      ENS_REGISTRY: Address.fromString('0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e'),
      PENDLE_ORACLE: Address.fromString('0x9a9fa8338dd5e5b2188006f1cd2ef26d921650c2'),
      SKY_USDS_PSM3: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDS: Address.fromString('0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
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
      EURC: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0x94b008aa00579c1307b0ef2c499ad98a8ce58e58'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_PRICE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_LENDING_POOL: Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
      AAVE_V3_DATA_PROVIDER: Address.fromString('0x7F23D86Ee20D869112572136221e173428DD740B'),
      AAVE_V3_ORACLE: Address.fromString('0xD81eb3728a631871a7eBBaD631b5f424909f0c77'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_1: Address.fromString('0x11DEE30E710B8d4a8630392781Cc3c0046365d4c'),
      ONE_INCH_ORACLE_2: Address.fromString('0x59Bc892E1832aE86C268fC21a91fE940830a52b0'),
      ONE_INCH_ORACLE_3: Address.fromString('0x52cbE0f49CcdD4Dc6E9C13BAb024EABD2842045B'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      AAVE_ORACLE: Address.fromString('0xD81eb3728a631871a7eBBaD631b5f424909f0c77'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      MORPHO: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      PENDLE_ORACLE: Address.fromString('0x9a9fa8338dd5e5b2188006f1cd2ef26d921650c2'),
      SKY_USDS_PSM3: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDS: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
    }
    return addresses
  } else if (network == 'base') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x4200000000000000000000000000000000000006'),
      WBTC: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDC: Address.fromString('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
      EURC: Address.fromString('0x60a3e35cc302bfa44cb288bc5a4f316fdb1adb42'),
      USDCE: Address.fromString('0x0000000000000000000000000000000000000000'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_PRICE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_LENDING_POOL: Address.fromString('0xA238Dd80C259a72e81d7e4664a9801593F98d1c5'),
      AAVE_V3_DATA_PROVIDER: Address.fromString('0xd82a47fdebB5bf5329b09441C3DaB4b5df2153Ad'),
      AAVE_V3_ORACLE: Address.fromString('0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_1: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      ONE_INCH_ORACLE_2: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_3: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_ORACLE: Address.fromString('0x2Cc0Fc26eD4563A5ce5e8bdcfe1A2878676Ae156'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0x0000000000000000000000000000000000000000'),
      MORPHO: Address.fromString('0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      PENDLE_ORACLE: Address.fromString('0x9a9fa8338dd5e5b2188006f1cd2ef26d921650c2'),
      SKY_USDS_PSM3: Address.fromString('0x1601843c5E9bC251A3272907010AFa41Fa18347E'),
      SUSDS: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
    }
    return addresses
  } else if (network == 'arbitrum-one') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x82af49447d8a07e3bd95bd0d56f35241523fbab1'),
      WBTC: Address.fromString('0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f'),
      USDC: Address.fromString('0xaf88d065e77c8cC2239327C5EDb3A432268e5831'),
      USDCE: Address.fromString('0xff970a61a04b1ca14834a43f5de4533ebddb5cc8'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      EURC: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_PRICE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_LENDING_POOL: Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
      AAVE_V3_DATA_PROVIDER: Address.fromString('0x7F23D86Ee20D869112572136221e173428DD740B'),
      AAVE_V3_ORACLE: Address.fromString('0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_1: Address.fromString('0x0AdDd25a91563696D8567Df78D5A01C9a991F9B8'),
      ONE_INCH_ORACLE_2: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_3: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_ORACLE: Address.fromString('0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'),
      MORPHO: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      PENDLE_ORACLE: Address.fromString('0x9a9fa8338dd5e5b2188006f1cd2ef26d921650c2'),
      SKY_USDS_PSM3: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDS: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
    }
    return addresses
  } else if (network == 'sonic-mainnet') {
    const addresses: ServiceAddresses = {
      WSTETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      STETH: Address.fromString('0x0000000000000000000000000000000000000000'),
      WETH: Address.fromString('0x50c42dEAcD8Fc9773493ED674b675bE577f2634b'),
      WBTC: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDC: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDCE: Address.fromString('0x29219dd400f2Bf60E5a23d13Be72B486D4038894'),
      DAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI: Address.fromString('0x0000000000000000000000000000000000000000'),
      EURC: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_PRICE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      FEED_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_V3_LENDING_POOL: Address.fromString('0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3'),
      AAVE_V3_DATA_PROVIDER: Address.fromString('0x306c124fFba5f2Bc0BcAf40D249cf19D492440b9'),
      AAVE_V3_ORACLE: Address.fromString('0xD63f7658C66B2934Bd234D79D06aEF5290734B30'),
      SPARK_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_DATA_PROVIDER: Address.fromString('0x0000000000000000000000000000000000000000'),
      SPARK_LENDING_POOL: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_1: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_2: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_3: Address.fromString('0x0000000000000000000000000000000000000000'),
      ONE_INCH_ORACLE_4: Address.fromString('0x0000000000000000000000000000000000000000'),
      AAVE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SDAI_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      ZERO_ADDRESS: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      USDT: Address.fromString('0x6047828dc181963ba44974801FF68e538dA5eaF9'),
      MORPHO: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REVERSE_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      ENS_REGISTRY: Address.fromString('0x0000000000000000000000000000000000000000'),
      PENDLE_ORACLE: Address.fromString('0x0000000000000000000000000000000000000000'),
      SKY_USDS_PSM3: Address.fromString('0x0000000000000000000000000000000000000000'),
      SUSDS: Address.fromString('0x0000000000000000000000000000000000000000'),
      USD: Address.fromString('0x0000000000000000000000000000000000000348'),
      ETH: Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      BTC: Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB'),
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
    aaveV3Oracle: AaveV3Oracle.bind(addresses.AAVE_V3_ORACLE),
    sparkOracle: SparkOracle.bind(addresses.SPARK_ORACLE),
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
