import prompts from 'prompts'
import { Address, Hex, encodeFunctionData, formatEther, parseAbi, parseEther } from 'viem'
import { ChainSetup, promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { buildCrossChainProposalAction } from '../../helpers/cross-chain-proposal'
import { promptForAddresses, useTestConfig } from '../../helpers/prompt-helpers'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
])

const summerTokenAbi = parseAbi([
  'function whitelistedAddresses(address account) view returns (bool)',
  'function addToWhitelist(address account)',
])

// Define an action interface for proposal actions.
interface Action {
  target: Address
  value: bigint
  calldata: Hex
}

// Builds whitelisting actions for the hub chain.
function buildHubWhitelistActions(addresses: Address[], tokenAddress: Address): Action[] {
  return addresses.map((addr) => ({
    target: tokenAddress,
    value: 0n,
    calldata: encodeFunctionData({
      abi: summerTokenAbi,
      functionName: 'addToWhitelist',
      args: [addr],
    }) as Hex,
  }))
}

async function buildSatelliteWhitelistActions(
  satelliteConfig: ChainSetup,
  addresses: Address[],
  governorAddress: Address,
): Promise<Action> {
  const satelliteTokenAddress = satelliteConfig.config.deployedContracts.gov.summerToken
    .address as Address

  const targets = addresses.map(() => satelliteTokenAddress)
  const values = addresses.map(() => 0n)
  const calldatas = addresses.map(
    (addr) =>
      encodeFunctionData({
        abi: summerTokenAbi,
        functionName: 'addToWhitelist',
        args: [addr],
      }) as Hex,
  )

  const description = `Add ${addresses.join(', ')} to SUMMER token whitelist on satellite chain (${satelliteConfig.name})`

  return buildCrossChainProposalAction({
    targetChain: satelliteConfig,
    targets,
    values,
    calldatas,
    description,
    governorAddress,
  })
}

/**
 * Generates a professional, formatted proposal description.
 * @param hubAddresses The list of hub addresses to whitelist.
 * @param satelliteProposals An array of objects describing satellite proposals.
 * @param forumPostUrl The URL for the forum post.
 * @param useTest Whether the test configuration is used.
 * @param fundTransferAmount (Optional) The amount of ETH (in wei) to transfer from the Timelock.
 * @returns A formatted string describing the proposal.
 */
function generateProposalDescription(
  hubAddresses: Address[],
  satelliteProposals: Array<{ chainName: string; addresses: Address[] }>,
  forumPostUrl: string,
  useTest: boolean,
  fundTransferAmount?: bigint,
): string {
  if (useTest) {
    return `Whitelist Reward Managers Proposal + Deposit (TEST v4)`
  }

  let description = `Proposal: Whitelist Fleet Reward Managers\n`
  description += '====================\n\n'
  description += 'Hub Chain (base):\n'
  if (hubAddresses.length > 0) {
    description += `  - Whitelist the following Fleet Reward Managers to enable rewards claiming: ${hubAddresses.join(', ')}\n`
  }
  if (fundTransferAmount !== undefined) {
    description += `  - Transfer ${formatEther(fundTransferAmount)} ETH from Timelock (Treasury) to Governor.\n`
  }
  description += '\n'

  if (satelliteProposals.length > 0) {
    description += 'Satellite Chains:\n'
    for (const proposal of satelliteProposals) {
      description += `  - For Satellite Chain (${proposal.chainName}): Whitelist the following Fleet Reward Managers to enable rewards claiming: ${proposal.addresses.join(', ')}\n`
    }
  }
  description += '\n'
  description +=
    'This proposal whitelists Fleet Reward Managers to allow rewards to be claimed on Hub and connected Satellite Chains.'
  description += '\n'
  description += `As outlined in this forum post: ${forumPostUrl}.`

  return description
}

async function promptForForumPostUrl(
  message: string = 'Enter the forum post URL:',
): Promise<string> {
  const response = await prompts({
    type: 'text',
    name: 'forumPostUrl',
    message,
    validate: (value: string) => {
      if (!value.startsWith('https://forum.summer.fi/')) {
        return 'Invalid forum post URL format. Must start with https://forum.summer.fi/'
      }
      return true
    },
  })
  return response.forumPostUrl
}

async function main() {
  const useTest = await useTestConfig()

  // ---------------- Hub Whitelisting ----------------
  const {
    config: hubConfig,
    chain,
    rpcUrl,
    name: hubChainName,
  } = await promptForChain('Select the hub chain:', useTest)
  const { publicClient, walletClient } = createClients(chain, rpcUrl)
  const hubInputAddresses = await promptForAddresses(
    'Enter addresses to whitelist on HUB chain (comma separated):',
  )

  // Extract addresses for the governor and token contracts.
  const GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const TOKEN_ADDRESS = hubConfig.deployedContracts.gov.summerToken.address as Address

  console.log('Hub Governor address:', GOVERNOR_ADDRESS)
  console.log('Hub Token address:', TOKEN_ADDRESS)

  // Check which hub addresses are not yet whitelisted.
  const hubAddressesToWhitelist: Address[] = []
  for (const addr of hubInputAddresses) {
    const isWhitelisted = await publicClient.readContract({
      address: TOKEN_ADDRESS,
      abi: summerTokenAbi,
      functionName: 'whitelistedAddresses',
      args: [addr],
    })
    if (isWhitelisted) {
      console.log(`Address ${addr} is already whitelisted on Hub chain, skipping.`)
    } else {
      hubAddressesToWhitelist.push(addr)
    }
  }

  if (hubAddressesToWhitelist.length === 0) {
    console.log('No new addresses to whitelist on Hub chain. Exiting.')
    return
  }

  console.log('==== Hub Whitelisting Summary ====')
  console.log(`Addresses to whitelist on Hub chain: ${hubAddressesToWhitelist.join(', ')}`)

  const hubActions = buildHubWhitelistActions(hubAddressesToWhitelist, TOKEN_ADDRESS)

  // ---------------- Optional: Fund Transfer from Timelock to Governor on Hub Chain ----------------
  const TIMELOCK_ADDRESS = hubConfig.deployedContracts.gov.timelock.address as Address
  const timelockBalance = await publicClient.getBalance({ address: TIMELOCK_ADDRESS })
  console.log(
    `Current Timelock balance on Hub chain (${TIMELOCK_ADDRESS}): ${formatEther(timelockBalance)} ETH`,
  )

  const { addFundTransfer } = await prompts({
    type: 'confirm',
    name: 'addFundTransfer',
    message:
      'Do you want to add an action to transfer funds from Timelock to Governor on Hub chain?',
    initial: false,
  })

  let fundTransferAmount: bigint | undefined = undefined
  if (addFundTransfer) {
    const { amount } = await prompts({
      type: 'text',
      name: 'amount',
      message: 'Enter amount of ETH to transfer from Timelock:',
      validate: (value: string) => !isNaN(Number(value)) || 'Please enter a valid number',
    })
    fundTransferAmount = parseEther(amount)
    if (timelockBalance < fundTransferAmount) {
      throw new Error(
        `Timelock balance (${formatEther(timelockBalance)} ETH) is less than transfer amount (${amount} ETH)`,
      )
    }
    const { confirmTransfer } = await prompts({
      type: 'confirm',
      name: 'confirmTransfer',
      message: `Confirm: Transfer ${amount} ETH from Timelock to Governor.`,
      initial: false,
    })
    if (!confirmTransfer) {
      console.log('Fund transfer action cancelled.')
      fundTransferAmount = undefined
    } else {
      const fundAction: Action = {
        target: GOVERNOR_ADDRESS,
        value: fundTransferAmount,
        calldata: '0x',
      }
      hubActions.push(fundAction)
      console.log(`Added fund transfer action: ${amount} ETH from Timelock to Governor.`)
    }
  }

  // ---------------- Satellite Whitelisting ----------------
  let satelliteActions: Action[] = []
  const satelliteProposals: Array<{ chainName: string; addresses: Address[] }> = []

  while (true) {
    const { addSatellite } = await prompts({
      type: 'confirm',
      name: 'addSatellite',
      message: 'Do you want to add a satellite chain proposal for whitelisting?',
      initial: false,
    })
    if (!addSatellite) break

    const satelliteConfig = await promptForTargetChain(hubChainName, useTest)

    // Prompt for satellite-specific addresses.
    const satelliteInputAddresses = await promptForAddresses(
      `Enter addresses to whitelist on satellite chain (${satelliteConfig.name}) (comma separated):`,
    )

    console.log(
      `Satellite Chain (${satelliteConfig.name}) input addresses: ${satelliteInputAddresses.join(', ')}`,
    )

    const actionContainingSatelliteProposal = await buildSatelliteWhitelistActions(
      satelliteConfig,
      satelliteInputAddresses,
      GOVERNOR_ADDRESS,
    )
    satelliteActions.push(actionContainingSatelliteProposal)
    satelliteProposals.push({ chainName: satelliteConfig.name, addresses: satelliteInputAddresses })

    console.log(`==== Satellite Whitelisting Summary for ${satelliteConfig.name} ====`)
    console.log(
      `Addresses to whitelist on satellite chain (${satelliteConfig.name}): ${satelliteInputAddresses.join(', ')}`,
    )
  }

  // ---------------- Combine Actions & Build Proposal ----------------
  const allActions = [...hubActions, ...satelliteActions]
  const targets: Address[] = allActions.map((action) => action.target)
  const values: bigint[] = allActions.map((action) => action.value)
  const calldatas: Hex[] = allActions.map((action) => action.calldata)

  const forumPostUrl = await promptForForumPostUrl()
  // Use the helper to generate a well-formatted proposal description.
  const proposalDescription = generateProposalDescription(
    hubAddressesToWhitelist,
    satelliteProposals,
    forumPostUrl,
    useTest,
    fundTransferAmount,
  )

  console.log('==== Final Proposal Summary ====')
  console.log('Proposal targets:', targets)
  console.log('Proposal values:', values)
  console.log('Proposal calldatas:', calldatas)
  console.log('Proposal description:\n', proposalDescription)

  try {
    console.log('Submitting whitelist proposal with multiple actions...')
    const txHash = await walletClient.writeContract({
      address: GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, proposalDescription],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })
    console.log('Whitelist proposal submitted. Transaction hash:', txHash)
    const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash })
    console.log('Proposal transaction mined. Block number:', receipt.blockNumber)
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
