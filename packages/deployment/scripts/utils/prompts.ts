import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import prompts from 'prompts'
import { Address, Chain, parseAbi } from 'viem'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { ChainName, getChainConfigs } from '../core/chain'
import { createClients } from '../core/clients'

dotenv.config({ path: '../../.env' })

export interface ChainSetup {
  name: ChainName
  config: BaseConfig
  chain: Chain
  rpcUrl: string
}

const fleetCommanderAbi = parseAbi([
  'function getConfig() view returns ((address bufferArk, uint256 minimumBufferBalance, uint256 depositCap, uint256 maxRebalanceOperations, address stakingRewardsManager))',
  'function name() view returns (string)',
])

const harborCommandAbi = parseAbi(['function getActiveFleetCommanders() view returns (address[])'])

/**
 * Prompts the user to continue with deployment
 * @param message Optional custom message
 * @returns Boolean indicating if user wants to continue
 */
export async function continueDeploymentCheck(message?: string) {
  const _message = message ?? 'Do you want to continue with the deployment?'

  const { confirmed } = await prompts({
    type: 'toggle',
    name: 'confirmed',
    initial: true,
    active: 'yes',
    inactive: 'no',
    message: _message,
  })

  return confirmed
}

/**
 * Prompts the user for addresses
 * @param message The prompt message
 * @returns Array of addresses
 */
export async function promptForAddresses(
  message: string = 'Enter the addresses to whitelist (comma separated):',
): Promise<Address[]> {
  const response = await prompts({
    type: 'text',
    name: 'addresses',
    message,
    validate: (value: string) => {
      const addresses = value.split(',').map((v) => v.trim())
      for (const addr of addresses) {
        if (!/^0x[a-fA-F0-9]{40}$/.test(addr)) {
          return `Invalid address format: ${addr}`
        }
      }
      return true
    },
  })
  return response.addresses.split(',').map((s: string) => s.trim())
}

/**
 * Prompts the user to select between Production and Test configuration
 * @returns Boolean indicating whether to use test config
 */
export async function useTestConfig(): Promise<boolean> {
  const { useTest } = await prompts({
    type: 'select',
    name: 'useTest',
    message: 'Select configuration to use:',
    choices: [
      { title: 'Production', value: false },
      { title: 'Test', value: true },
    ],
  })

  return useTest
}

/**
 * Prompts the user to select between Production and Bummer/Test configuration
 * @returns A boolean indicating whether to use the Bummer/Test config (true) or Production config (false)
 */
export async function promptForConfigType(): Promise<boolean> {
  const configResponse = await prompts({
    type: 'select',
    name: 'configType',
    message: 'Select the configuration to use:',
    choices: [
      { title: 'Production Config', value: false },
      { title: 'Bummer (Test) Config', value: true },
    ],
  })

  return configResponse.configType as boolean
}

/**
 * Simple yes/no prompt helper
 * @param question The question to ask the user
 * @returns A boolean indicating the user's choice
 */
export async function promptYesNo(question: string): Promise<boolean> {
  const response = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: question,
    initial: false,
  })

  return response.confirmed || false
}

/**
 * Prompts the user for the chain selection (manual prompt).
 */
export async function promptForChain(
  message = 'Which chain would you like to execute this operation on?',
  useTestConfig = false,
): Promise<ChainSetup> {
  console.log(`Using ${useTestConfig ? 'test' : 'production'} config in promptForChain`)
  const chainConfigs = getChainConfigs(useTestConfig)
  const chainOptions = Object.keys(chainConfigs).map((key) => ({
    title: key,
    value: { name: key as ChainName, ...chainConfigs[key as ChainName] },
  }))

  const { selectedChain } = await prompts({
    type: 'select',
    name: 'selectedChain',
    message,
    choices: chainOptions,
  })

  if (!selectedChain) throw new Error('No chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to execute on ${selectedChain.name}`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedChain
}

/**
 * Automatically infers the chain from hre and asks the user to confirm.
 *
 * Instead of prompting the user with a list of chains, this function uses the detected
 * chainId (from hre.network.config.chainId) to look up its configuration from chainConfigs.
 */
export async function promptForChainFromHre(
  message = 'Do you want to execute this operation on the current network?',
  useTestConfig = false,
): Promise<ChainSetup> {
  console.log(`Using ${useTestConfig ? 'test' : 'production'} config in promptForChainFromHre`)

  const chainConfigs = getChainConfigs(useTestConfig)
  // Get chain id from Hardhat runtime environment.
  const detectedChainId = hre.network.config.chainId
  // Find the matching chain config by comparing the chain.id value.
  const entry = Object.entries(chainConfigs).find(([_, config]) => {
    return config.chain.id === detectedChainId
  })

  if (!entry) {
    throw new Error(`Chain with id ${detectedChainId} not found in chainConfigs`)
  }

  const [chainName, config] = entry
  // Build the ChainSetup object (same structure returned by promptForChain).
  const chainSetup: ChainSetup = { name: chainName as ChainName, ...config }

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `${message} ${chainSetup.name} (chainId ${detectedChainId})?`,
    initial: true,
  })
  if (!confirmed) throw new Error('Operation cancelled by user')

  return chainSetup
}

/**
 * Prompts for a target chain (different from current chain)
 */
export async function promptForTargetChain(
  currentChain: ChainName,
  useTestConfig = false,
): Promise<ChainSetup> {
  console.log(`Using ${useTestConfig ? 'test' : 'production'} config in promptForTargetChain`)
  const chainConfigs = getChainConfigs(useTestConfig)
  const chainOptions = Object.entries(chainConfigs)
    .filter(([key]) => key !== currentChain)
    .map(([key]) => ({
      title: key,
      value: { name: key as ChainName, ...chainConfigs[key as ChainName] },
    }))

  const { selectedChain } = await prompts({
    type: 'select',
    name: 'selectedChain',
    message: 'Which chain would you like to set as the target?',
    choices: chainOptions,
  })

  if (!selectedChain) throw new Error('No target chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to set ${selectedChain.name} as the target chain`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedChain
}

/**
 * Prompts the user to select a fleet for rewards setup
 */
export async function promptForFleet(
  chainName: ChainName,
  targetConfig: BaseConfig,
  targetChain: Chain,
  targetRpcUrl: string,
): Promise<{
  fleetConfig: FleetConfig
  rewardsManagerAddress: Address
}> {
  const { publicClient } = createClients(targetChain, targetRpcUrl)

  // Get all fleet configuration files from the fleets directory
  const fleetsDir = path.join(__dirname, '../../config/fleets')
  const fleetFiles = fs
    .readdirSync(fleetsDir)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => {
      // Load each file and check if it matches the chain
      const fleetConfig = JSON.parse(fs.readFileSync(path.join(fleetsDir, file), 'utf8'))
      return fleetConfig.network.toLowerCase() === chainName.toLowerCase()
    })

  if (fleetFiles.length === 0) {
    throw new Error(`No fleet configurations found for chain ${chainName}`)
  }

  // Create choices array for the prompt
  const choices = await Promise.all(
    fleetFiles.map(async (file) => {
      const config = JSON.parse(fs.readFileSync(path.join(fleetsDir, file), 'utf8'))
      return {
        title: `${config.fleetName} (${config.symbol}) - ${config.assetSymbol} ${
          config.isBummer ? '(Bummer)' : ''
        }`,
        value: config,
      }
    }),
  )

  // Prompt user to select a fleet
  const { selectedFleet } = await prompts({
    type: 'select',
    name: 'selectedFleet',
    message: 'Select a fleet to add rewards to:',
    choices,
  })

  if (!selectedFleet) {
    throw new Error('No fleet selected')
  }

  console.log('Selected Fleet:', selectedFleet.fleetName)
  const harborCommandAddress = targetConfig.deployedContracts.core.harborCommand.address

  console.log('HarborCommand address:', harborCommandAddress)

  // Get all active fleet commanders from HarborCommand
  const activeFleetCommanders = (await publicClient.readContract({
    address: harborCommandAddress as Address,
    abi: harborCommandAbi,
    functionName: 'getActiveFleetCommanders',
  })) as Address[]

  console.log('\nActive Fleet Commanders:')

  // Find the fleet commander address by matching names
  let matchedFleetCommander: Address | undefined
  for (const commander of activeFleetCommanders) {
    const fleetName = (await publicClient.readContract({
      address: commander,
      abi: fleetCommanderAbi,
      functionName: 'name',
    })) as string

    console.log(`- Address: ${commander}`)
    console.log(`  Name: ${fleetName}`)

    if (fleetName === selectedFleet.fleetName) {
      matchedFleetCommander = commander
      console.log('  ✓ Matched!')
    }
  }

  if (!matchedFleetCommander) {
    throw new Error(`No active fleet commander found for fleet ${selectedFleet.fleetName}`)
  }

  console.log('\nSelected Fleet Commander:', matchedFleetCommander)

  // Get fleet config using the matched fleet commander address
  const fleetConfig = (await publicClient.readContract({
    address: matchedFleetCommander,
    abi: fleetCommanderAbi,
    functionName: 'getConfig',
  })) as any

  const rewardsManagerAddress = fleetConfig.stakingRewardsManager as Address

  if (
    !rewardsManagerAddress ||
    rewardsManagerAddress === '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error(`No rewards manager found for fleet ${selectedFleet.fleetName}`)
  }

  // Confirm selection
  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to add rewards to ${selectedFleet.fleetName} (Rewards Manager: ${rewardsManagerAddress})`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return {
    fleetConfig: selectedFleet,
    rewardsManagerAddress,
  }
}
