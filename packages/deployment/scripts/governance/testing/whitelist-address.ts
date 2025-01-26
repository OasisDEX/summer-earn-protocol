import prompts from 'prompts'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { promptForChain } from '../../helpers/chain-prompt'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
])

const summerTokenAbi = parseAbi([
  'function whitelistedAddresses(address account) view returns (bool)',
  'function addToWhitelist(address account)',
])

async function promptForAddress(): Promise<Address> {
  const response = await prompts({
    type: 'text',
    name: 'address',
    message: 'Enter the address to whitelist:',
    validate: (value) => /^0x[a-fA-F0-9]{40}$/.test(value) || 'Invalid address format',
  })
  return response.address as Address
}

async function main() {
  // Get chain configuration
  const { config: hubConfig, chain, rpcUrl } = await promptForChain('Select chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get address to whitelist
  const addressToWhitelist = await promptForAddress()

  // Extract addresses
  const GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const TOKEN_ADDRESS = hubConfig.deployedContracts.gov.summerToken.address as Address

  // Check if address is already whitelisted
  const isWhitelisted = await publicClient.readContract({
    address: TOKEN_ADDRESS,
    abi: summerTokenAbi,
    functionName: 'whitelistedAddresses',
    args: [addressToWhitelist],
  })

  if (isWhitelisted) {
    console.log('Address is already whitelisted')
    return
  }

  // Create proposal
  const targets = [TOKEN_ADDRESS]
  const values = [0n]
  const calldatas = [
    encodeFunctionData({
      abi: summerTokenAbi,
      functionName: 'addToWhitelist',
      args: [addressToWhitelist],
    }) as Hex,
  ]
  const description = `Add ${addressToWhitelist} to SUMMER token whitelist`

  try {
    console.log('Submitting whitelist proposal...')
    const hash = await walletClient.writeContract({
      address: GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Whitelist proposal submitted. Transaction hash:', hash)
  } catch (error: any) {
    console.error('Error submitting proposal:', error)
    if (error.cause) {
      console.error('Error cause:', error.cause)
      if (error.cause.data) {
        console.error('Error data:', error.cause.data)
      }
    }
  }
}

main().catch(console.error)
