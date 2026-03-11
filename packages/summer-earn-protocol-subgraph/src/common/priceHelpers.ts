import {
  Address,
  BigDecimal,
  BigInt,
  dataSource,
  ethereum,
  log,
  TypedMap,
} from '@graphprotocol/graph-ts'
import { TokenPrice as TokenPriceEntity } from '../../generated/schema'
import { addresses, getOneInchOracle, services } from './addressProvider'
import { BigDecimalConstants, BigIntConstants } from './constants'
import { getOrCreateToken } from './initializers'

export class TokenPrice {
  price: BigDecimal
  oracle: string

  constructor(price: BigDecimal, oracle: string) {
    this.price = price
    this.oracle = oracle
  }
}

// In-memory cache for price lookups during interval processing
// Key: tokenAddress.toHexString(), Value: TokenPrice
let priceCache: TypedMap<string, TokenPrice> | null = null

/**
 * Initialize the price cache for interval processing.
 * Call this at the start of handleInterval to enable caching.
 */
export function initPriceCache(): void {
  priceCache = new TypedMap<string, TokenPrice>()
}

/**
 * Clear the price cache after interval processing.
 * Call this at the end of handleInterval to free memory.
 */
export function clearPriceCache(): void {
  priceCache = null
}

export function getTokenPriceInUSD(tokenAddress: Address, block: ethereum.Block): TokenPrice {
  // Check in-memory cache first if available
  const cache = priceCache
  if (cache != null) {
    const cacheKey = tokenAddress.toHexString()
    const cachedPrice = cache.get(cacheKey)
    if (cachedPrice != null) {
      return cachedPrice
    }
  }

  const token = getOrCreateToken(tokenAddress)
  let existingPrice = TokenPriceEntity.load(tokenAddress)
  if (existingPrice == null) {
    existingPrice = new TokenPriceEntity(tokenAddress)
  } else if (existingPrice && existingPrice.blockNumber.equals(block.number)) {
    const price = new TokenPrice(existingPrice.price, existingPrice.oracle)
    // Cache the result
    if (cache != null) {
      cache.set(tokenAddress.toHexString(), price)
    }
    return price
  }
  const price = _getTokenPriceInUSD(tokenAddress, block.number)
  existingPrice.price = price.price
  existingPrice.oracle = price.oracle
  existingPrice.blockNumber = block.number
  existingPrice.token = tokenAddress.toHexString()
  existingPrice.save()

  token.lastPriceUSD = price.price
  token.lastPriceBlockNumber = block.number
  token.save()

  // Cache the result
  if (cache != null) {
    cache.set(tokenAddress.toHexString(), price)
  }

  return price
}

/**
 * Returns the price of a token in USD, using Chainlink, Aave or 1inch oracles.
 * @param {Address} tokenAddress - The address of the token to get the price for.
 * @returns {BigInt} - The price of the token in USD, in Chainlink precision with 8 decimals.
 */
export function _getTokenPriceInUSD(tokenAddress: Address, blockNumber: BigInt): TokenPrice {
  if (tokenAddress == addresses.SDAI) {
    const sDaiOracleResult = services.sDaiOracle.try_latestAnswer()
    if (!sDaiOracleResult.reverted) {
      return new TokenPrice(
        sDaiOracleResult.value.toBigDecimal().div(BigDecimalConstants.CHAIN_LINK_PRECISION),
        'sDaiOracle',
      )
    }
  }
  if (tokenAddress == addresses.SUSDE) {
    const susdeOracleResult = services.susdeOracle.try_price()
    if (!susdeOracleResult.reverted) {
      return new TokenPrice(
        susdeOracleResult.value.toBigDecimal().div(BigDecimalConstants.MORPHO_PRECISION),
        'susdeOracle',
      )
    }
  }
  if (dataSource.network() == 'mainnet') {
    const referenceToken = getChainlinkReferenceToken(tokenAddress)
    const chainlinkResult = services.feedRegistry.try_latestRoundData(referenceToken, addresses.USD)
    if (!chainlinkResult.reverted) {
      // for oraclelesss mode compability
      return new TokenPrice(
        chainlinkResult.value
          .getAnswer()
          .toBigDecimal()
          .div(BigDecimalConstants.CHAIN_LINK_PRECISION),
        'chainlink',
      )
    }
  }

  const referenceToken = getAaveReferenceToken(tokenAddress)
  const aaveResult = services.aaveV3Oracle.try_getAssetPrice(referenceToken)
  if (!aaveResult.reverted && aaveResult.value.toBigDecimal().gt(BigDecimalConstants.ZERO)) {
    return new TokenPrice(
      aaveResult.value.toBigDecimal().div(BigDecimalConstants.CHAIN_LINK_PRECISION),
      'aaveOracle',
    )
  }

  const hyperLendResult = services.hyperLendOracle.try_getAssetPrice(tokenAddress)
  if (
    !hyperLendResult.reverted &&
    hyperLendResult.value.toBigDecimal().gt(BigDecimalConstants.ZERO)
  ) {
    return new TokenPrice(
      hyperLendResult.value.toBigDecimal().div(BigDecimalConstants.CHAIN_LINK_PRECISION),
      'hyperLendOracle',
    )
  }

  const oneInchOracle = getOneInchOracle(blockNumber)

  if (oneInchOracle) {
    const quoteToken = dataSource.network() == 'base' ? addresses.USDC : addresses.USDT
    const quotePrecision =
      dataSource.network() == 'base'
        ? BigIntConstants.USDC_PRECISION
        : BigIntConstants.USDT_PRECISION
    const oneInchResult = oneInchOracle.try_getRate(referenceToken, quoteToken, true)
    if (
      !oneInchResult.reverted &&
      oneInchResult.value.toBigDecimal().gt(BigDecimalConstants.ZERO)
    ) {
      const token = getOrCreateToken(referenceToken)
      // eg for weth (18 decimals) /usdc (6 decimals) we get 2226797259
      // we need to multiply by 10^18 and divide by 10^6 and divide by 10^18 -> 2226.797259
      // for usdbc (6 decimals) /usdc (6 decimals) we get  1000519762896303783
      // we need to multiply by 10^6 and divide by 10^6 and divide by 10^18 -> 1.000519762896303783
      return new TokenPrice(
        oneInchResult.value
          // @ts-ignore - assembly script
          .times(BigIntConstants.TEN.pow(token.decimals as u8))
          .div(quotePrecision)
          .toBigDecimal()
          .div(BigDecimalConstants.WAD),
        `oneInchOracle-${oneInchOracle._address.toHexString()}`,
      )
    } else {
      log.error('oneInchOracle not found', [])
    }
  }
  return new TokenPrice(BigDecimalConstants.ZERO, 'fallback')
}
/**
 * Returns the reference token for a given token address.
 * If the token is WETH, returns ETH.
 * If the token is WBTC, returns BTC.
 * Otherwise, returns the original token address.
 * @param {Address} tokenAddress - The address of the token to get the reference token for.
 * @returns {Address} - The reference token address.
 */
export function getReferenceToken(tokenAddress: Address): Address {
  let referenceToken = tokenAddress

  if (tokenAddress.toHexString().toLowerCase() == addresses.WETH.toHexString().toLowerCase()) {
    referenceToken = addresses.ETH
  }

  if (tokenAddress.toHexString().toLowerCase() == addresses.WBTC.toHexString().toLowerCase()) {
    referenceToken = addresses.BTC
  }

  return referenceToken
}

/**
 * Retrieves the Aave reference token for a given Chainlink denomination token address.
 * If the token address is ETH, it returns the WETH address.
 * If the token address is BTC, it returns the WBTC address.
 * @param tokenAddress The token address for which to retrieve the Aave reference token.
 * @returns The Aave reference token address.
 */
function getAaveReferenceToken(tokenAddress: Address): Address {
  let referenceToken = tokenAddress

  if (tokenAddress.toHexString().toLowerCase() == addresses.ETH.toHexString().toLowerCase()) {
    referenceToken = addresses.WETH
  }
  if (tokenAddress.toHexString().toLowerCase() == addresses.BTC.toHexString().toLowerCase()) {
    referenceToken = addresses.WBTC
  }

  return referenceToken
}

/**
 * Retrieves the Chainlink reference token address based on the provided token address.
 * If the token address is WETH, it returns the address of ETH.
 * If the token address is WBTC, it returns the address of BTC.
 * @dev in transfer function ETH is referenced as 0xeee... and BTC as 0xbbb... hence the swap
 * @param tokenAddress The token address for which to retrieve the reference token address.
 * @returns The reference token address.
 */
function getChainlinkReferenceToken(tokenAddress: Address): Address {
  let referenceToken = tokenAddress

  if (tokenAddress.toHexString().toLowerCase() == addresses.WETH.toHexString().toLowerCase()) {
    referenceToken = addresses.ETH
  }

  if (tokenAddress.toHexString().toLowerCase() == addresses.WBTC.toHexString().toLowerCase()) {
    referenceToken = addresses.BTC
  }

  return referenceToken
}
