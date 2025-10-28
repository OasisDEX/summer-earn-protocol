import hre from 'hardhat'
import kleur from 'kleur'
import { PublicClient } from 'viem'
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
      const code = await publicClient.getBytecode({
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
}

/**
 * Legacy function for backward compatibility
 * @deprecated Use StargateContractValidator class instead
 */
export async function validateStargateContract(contractAddress: string): Promise<boolean> {
  const validator = new StargateContractValidator()
  return validator.validateContract(contractAddress)
}
