import { Address, BigDecimal, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/HarborCommand/ERC20'
import * as constants from '../common/constants'

export function enumToPrefix(snake: string): string {
  return snake.toLowerCase().replace('_', '-') + '-'
}

export function prefixID(enumString: string, ID: string): string {
  return enumToPrefix(enumString) + ID
}

export function readValue<T>(callResult: ethereum.CallResult<T>, defaultValue: T): T {
  return callResult.reverted ? defaultValue : callResult.value
}

export function getTokenDecimals(tokenAddr: Address): BigDecimal {
  const token = ERC20Contract.bind(tokenAddr)

  const decimals = readValue<BigInt>(token.try_decimals(), constants.DEFAULT_DECIMALS)

  return constants.BIGINT_TEN.pow(decimals.toI32() as u8).toBigDecimal()
}

/**
 * Converts an amount in base units to WAD units, based on the given precision.
 * @param {BigInt} amountInBaseUnit - The amount in base units to convert.
 * @param {BigInt} precision - The precision of the token.
 * @returns {BigInt} - The amount in WAD units.
 */
export function formatAmount(amountInBaseUnit: BigInt, decimals: BigInt): BigDecimal {
  const len = decimals.toI32() + 1
  const power = BigDecimal.fromString('10'.padEnd(len, '0'))

  return BigDecimal.fromString(amountInBaseUnit.toString()).div(power)
}

/**
 * Formats the position ID by concatenating the vault ID and account ID.
 * @param vaultID - The ID of the vault.
 * @param accountID - The ID of the account.
 * @returns The formatted position ID.
 */
export function formatPositionId(vaultID: string, accountID: string): string {
  return vaultID + '-' + accountID
}

/**
 * Splits the given position ID into an array containing the account ID and vault ID.
 * @param positionId - The position ID to split.
 * @returns An array containing the account ID and vault ID.
 */
export function getAccountIdAndVaultIdFromPositionId(positionId: string): string[] {
  return positionId.split('-')
}

/**
 * Calculates the Annual Percentage Rate (APR) for a given time period.
 *
 * @param previousPricePerShare - The previous price per share.
 * @param currentPricePerShare - The current price per share.
 * @param deltaTime - The time elapsed between the previous and current prices.
 * @returns The calculated APR.
 */
export function getAprForTimePeriod(
  previousPricePerShare: BigDecimal,
  currentPricePerShare: BigDecimal,
  deltaTime: BigDecimal,
): BigDecimal {
  if (deltaTime.equals(constants.BigDecimalConstants.ZERO)) {
    return constants.BigDecimalConstants.ZERO
  }

  const amountOfPeriodsInYear = constants.BigDecimalConstants.YEAR_IN_SECONDS.div(deltaTime)
  return currentPricePerShare
    .minus(previousPricePerShare)
    .div(previousPricePerShare)
    .times(constants.BigDecimalConstants.HUNDRED)
    .times(amountOfPeriodsInYear)
}
