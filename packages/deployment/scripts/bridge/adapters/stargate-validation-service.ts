import hre from 'hardhat'
import kleur from 'kleur'
import { PublicClient } from 'viem'
import { ADDRESS_ZERO } from '../../lib/infrastructure/constants'
import { STARGATE_COMMON_ABI, STARGATE_OFT_ABI, STARGATE_POOL_ABI } from './abis'

/**
 * Validates Stargate contracts with caching to avoid repeated validation
 */
export class StargateContractValidator {
  private validatedContracts = new Set<string>()

  /**
   * Validate a Stargate contract with caching
   */
  async validateContract(contractAddress: string): Promise<boolean> {
    const contractKey = contractAddress.toLowerCase()

    if (this.validatedContracts.has(contractKey)) {
      console.log(kleur.blue(`✓ Stargate contract ${contractAddress} already validated`))
      return true
    }

    const isValid = await this.validateStargateContract(contractAddress)
    if (isValid) {
      this.validatedContracts.add(contractKey)
      console.log(kleur.green(`✓ Stargate contract ${contractAddress} validated`))
    } else {
      console.error(kleur.red(`Invalid Stargate contract ${contractAddress}: Failed validation`))
    }

    return isValid
  }

  /**
   * Validate Stargate contract by trying different contract types
   */
  private async validateStargateContract(contractAddress: string): Promise<boolean> {
    try {
      const publicClient = await hre.viem.getPublicClient()

      // Try OFT-style contract (has stargateType function)
      if (await this.validateOFTContract(publicClient, contractAddress)) {
        return true
      }

      // Try Pool-style contract (has token function)
      if (await this.validatePoolContract(publicClient, contractAddress)) {
        return true
      }

      // Try common Stargate functions
      if (await this.validateCommonContract(publicClient, contractAddress)) {
        return true
      }

      // Final check: just verify it's a contract
      return await this.validateContractExists(publicClient, contractAddress)
    } catch (error) {
      console.error(kleur.red(`Error validating Stargate contract ${contractAddress}:`), error)
      return false
    }
  }

  /**
   * Validate OFT-style Stargate contract
   */
  private async validateOFTContract(
    publicClient: PublicClient,
    contractAddress: string,
  ): Promise<boolean> {
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: STARGATE_OFT_ABI,
        functionName: 'stargateType',
      })
      return true
    } catch {
      return false
    }
  }

  /**
   * Validate Pool-style Stargate contract
   */
  private async validatePoolContract(
    publicClient: PublicClient,
    contractAddress: string,
  ): Promise<boolean> {
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: STARGATE_POOL_ABI,
        functionName: 'token',
      })
      return true
    } catch {
      return false
    }
  }

  /**
   * Validate common Stargate contract
   */
  private async validateCommonContract(
    publicClient: PublicClient,
    contractAddress: string,
  ): Promise<boolean> {
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: STARGATE_COMMON_ABI,
        functionName: 'localDecimals',
      })
      return true
    } catch {
      return false
    }
  }

  /**
   * Validate that contract exists (has bytecode)
   */
  private async validateContractExists(
    publicClient: PublicClient,
    contractAddress: string,
  ): Promise<boolean> {
    try {
      const code = await publicClient.getCode({
        address: contractAddress as `0x${string}`,
      })
      return code !== undefined && code !== '0x'
    } catch {
      return false
    }
  }

  /**
   * Clear validation cache (useful for testing)
   */
  clearCache(): void {
    this.validatedContracts.clear()
  }

  /**
   * Get number of validated contracts in cache
   */
  getCacheSize(): number {
    return this.validatedContracts.size
  }

  /**
   * Get the token address from a Stargate pool contract
   * @param contractAddress The Stargate contract address
   * @returns The token address, or null if not found
   */
  async getStargatePoolToken(contractAddress: string): Promise<string | null> {
    try {
      const publicClient = await hre.viem.getPublicClient()
      const tokenAddress = await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: STARGATE_POOL_ABI,
        functionName: 'token',
      })
      return tokenAddress as string
    } catch (error) {
      console.error(
        kleur.red(`Error getting token from Stargate contract ${contractAddress}:`),
        error,
      )
      return null
    }
  }

  /**
   * Validate that the Stargate contract's token matches the expected asset address
   * @param assetAddress The expected asset address
   * @param stargateContract The Stargate contract address
   * @returns Object with isValid flag and error message if invalid
   */
  async validateTokenMatch(
    assetAddress: string,
    stargateContract: string,
  ): Promise<{ isValid: boolean; error?: string; actualToken?: string }> {
    const checksummedAsset = assetAddress.toLowerCase()
    const checksummedStargate = stargateContract.toLowerCase()

    const actualToken = await this.getStargatePoolToken(checksummedStargate)
    if (!actualToken) {
      return {
        isValid: false,
        error: `Could not retrieve token address from Stargate contract ${stargateContract}`,
      }
    }

    const checksummedActualToken = actualToken.toLowerCase()

    // Handle native ETH pools: Stargate uses zero address for native ETH pools
    // The StargateAdapter contract cannot accept zero address assets (reverts InvalidAssetAddress)
    // and requires poolToken == asset, so native ETH pools are not supported by the current adapter implementation
    // Note: Stargate itself supports native ETH pools, but the adapter uses IERC20 which requires ERC20 tokens
    if (checksummedActualToken === ADDRESS_ZERO) {
      return {
        isValid: false,
        error: `Native ETH pools are not supported by StargateAdapter contract (uses IERC20 which requires ERC20 tokens, not native ETH)`,
        actualToken: actualToken,
      }
    }

    if (checksummedActualToken !== checksummedAsset) {
      return {
        isValid: false,
        error: `Token mismatch: expected ${assetAddress}, but Stargate contract ${stargateContract} has token ${actualToken}`,
        actualToken,
      }
    }

    return { isValid: true }
  }
}

/**
 * Legacy function for backward compatibility
 * @deprecated Use StargateContractValidator class instead
 */
export async function validateStargateContract(contractAddress: string): Promise<boolean> {
  const validator = new StargateContractValidator()
  return validator.validateContract(contractAddress)
}
