import fs from 'fs'
import path from 'path'
import prompts from 'prompts'
import { Address, Chain, parseAbi } from 'viem'
import { FleetConfig } from '../../types/config-types'
import { ChainConfig, ChainName } from './chain-prompt'
import { createClients } from './wallet-helper'

const fleetCommanderAbi = parseAbi([
  'function getConfig() view returns ((address bufferArk, uint256 minimumBufferBalance, uint256 depositCap, uint256 maxRebalanceOperations, address stakingRewardsManager))',
  'function name() view returns (string)',
])

const harborCommandAbi = parseAbi(['function getActiveFleetCommanders() view returns (address[])'])

export async function promptForFleet(
  chainName: ChainName,
  targetConfig: ChainConfig,
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
        title: `${config.fleetName} (${config.symbol}) - ${config.assetSymbol}`,
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
