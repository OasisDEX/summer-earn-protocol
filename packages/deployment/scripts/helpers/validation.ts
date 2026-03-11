import { Address } from 'viem'
import { BaseConfig, Token } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { ArkDetailsSchema, VaultNameSchema, type ArkDetails } from './zod-schemas'

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

export function validateConfigAddressEntry(
  fragment: Record<string, unknown>,
  key: unknown,
  context: string,
): Address {
  const validatedKey = validateString(key, `${context} key`)
  const value = fragment[validatedKey]
  if (value === undefined) {
    const availableKeys = Object.keys(fragment)
    throw new ValidationError(
      `Invalid ${context}: key "${validatedKey}" not found. Available keys: ${availableKeys.join(', ')}`,
    )
  }
  return validateAddress(value, context)
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
 * Validates vault name format to ensure it follows the protocol_name convention.
 * The vault name must contain at least one underscore with a non-empty protocol prefix.
 *
 * @param vaultName - The vault name to validate
 * @param context - Context string for error messages
 * @returns Validated vault name string
 * @throws ValidationError if validation fails
 */
export function validateVaultName(vaultName: unknown, context: string = 'vault name'): string {
  try {
    return VaultNameSchema.parse(vaultName)
  } catch (error) {
    if (error instanceof Error) {
      throw new ValidationError(`Invalid ${context}: ${error.message}`)
    }
    throw new ValidationError(`Invalid ${context}: validation failed`)
  }
}
