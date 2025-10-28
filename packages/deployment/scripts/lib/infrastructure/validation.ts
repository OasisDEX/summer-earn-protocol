import { Address } from 'viem'
import { BaseConfig, Token } from '../../../../types/config-types'
import { ADDRESS_ZERO } from './constants'
import { ArkDetailsSchema, type ArkDetails } from './zod-schemas'

export class ValidationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ValidationError'
  }
}

export function validateNumber(value: unknown, context: string, min: number, max: number): number {
  if (typeof value !== 'number' || isNaN(value) || value < min || value > max) {
    throw new ValidationError(`Invalid ${context}: must be a number between ${min} and ${max}`)
  }
  return value
}

export function validateAddress(address: unknown, context: string): Address {
  if (!address || typeof address !== 'string') {
    throw new ValidationError(`Invalid ${context}: address must be a string`)
  }
  if (address === ADDRESS_ZERO) {
    throw new ValidationError(`Invalid ${context}: cannot be zero address`)
  }
  if (!address.startsWith('0x')) {
    throw new ValidationError(`Invalid ${context}: must start with 0x`)
  }
  return address as Address
}

export function validateString(value: unknown, context: string, minLength = 1): string {
  if (!value || typeof value !== 'string') {
    throw new ValidationError(`Invalid ${context}: must be a non-empty string`)
  }
  if (value.length < minLength) {
    throw new ValidationError(`Invalid ${context}: must be at least ${minLength} characters`)
  }
  return value
}

export function validateToken(config: BaseConfig, token: string): Token {
  const normalizedToken = token.toLowerCase()
  // This ensures the token exists in Token
  if (!Object.values(Token).includes(normalizedToken as Token)) {
    throw new ValidationError(`Invalid token type: ${token}`)
  }
  if (
    !config.tokens[normalizedToken as Token] ||
    config.tokens[normalizedToken as Token] === ADDRESS_ZERO
  ) {
    throw new ValidationError(`Invalid token: ${token}`)
  }
  return normalizedToken as Token
}

export function validateDeployedContracts(config: any) {
  if (!config.deployedContracts) {
    throw new ValidationError('Missing deployedContracts configuration')
  }

  // Validate core contracts
  validateAddress(
    config.deployedContracts.core?.configurationManager?.address,
    'configurationManager address',
  )

  // Validate governance contracts
  validateAddress(
    config.deployedContracts.gov?.protocolAccessManager?.address,
    'protocolAccessManager address',
  )
}

export function validateProtocolConfig(config: any, protocol: string) {
  if (!config.protocolSpecific?.[protocol]) {
    throw new ValidationError(`Missing ${protocol} protocol configuration`)
  }
  return config.protocolSpecific[protocol]
}

export function validateMarketId(marketId: unknown, context: string) {
  const validatedMarketId = validateString(marketId, context)
  if (!validatedMarketId.startsWith('0x')) {
    throw new ValidationError(`Invalid ${context}: market ID must start with 0x`)
  }
  return validatedMarketId
}

export function validateErc4626Address(address: unknown, context: string) {
  const validatedAddress = validateAddress(address, context)
  if (!validatedAddress.startsWith('0x')) {
    throw new ValidationError(`Invalid ${context}: vault address must start with 0x`)
  }
  return validatedAddress
}

/**
 * Validates ark details object to ensure it contains the minimal required fields
 * for offchain processing: protocol (string), pool (Address), and chainId (number).
 *
 * @param details - The ark details object to validate
 * @param context - Context string for error messages
 * @returns Validated ark details object
 * @throws ValidationError if validation fails
 */
export function validateArkDetails(details: unknown, context: string = 'ark details'): ArkDetails {
  try {
    return ArkDetailsSchema.parse(details)
  } catch (error) {
    if (error instanceof Error) {
      throw new ValidationError(`Invalid ${context}: ${error.message}`)
    }
    throw new ValidationError(`Invalid ${context}: validation failed`)
  }
}

/**
 * Retrieves the asset address from the config based on the asset symbol.
 * @param {string} assetSymbol - The symbol of the asset.
 * @param {BaseConfig} config - The configuration object.
 * @returns {string} The address of the asset.
 * @throws {Error} If the asset symbol is not found in the config.
 */
export function getAssetAddress(assetSymbol: string, config: BaseConfig): string {
  const assetSymbolLower = assetSymbol.toLowerCase() as keyof typeof config.tokens
  if (!Object.keys(config.tokens).includes(assetSymbolLower)) {
    throw new Error(`No token address for symbol ${assetSymbol} found in config`)
  }
  return config.tokens[assetSymbolLower]
}
