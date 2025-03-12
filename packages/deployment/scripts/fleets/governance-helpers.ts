import hre from 'hardhat'
import kleur from 'kleur'
import _ from 'lodash'
import path from 'path'
import { Address, encodeFunctionData, Hex, parseAbi, PublicClient } from 'viem'
import SummerTokenABI from '../../artifacts/src/contracts/SummerToken.sol/SummerToken.json'
import { FleetContracts } from '../../ignition/modules/fleet'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigByChainId } from '../helpers/chain-configs'
import { getConfigByNetwork } from '../helpers/config-handler'
import { hashDescription } from '../helpers/hash-description'
import { prepareBridgeTransaction } from '../helpers/layerzero-bridge-helpers'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal, ProposalContent } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'
import { getRewardsManagerAddress } from './fleet-deployment-helpers'

export interface FleetSingleChainContent extends ProposalContent {
  sourceDescription: string
  sourceTitle: string
}

export interface FleetCrossChainContent extends FleetSingleChainContent {
  destinationDescription: string
}

/**
 * Generates a formatted description for a fleet deployment proposal
 */
export async function generateFleetProposalDescription(
  deployedFleet: FleetContracts,
  fleetDefinition: FleetConfig,
  deployedArkAddresses: Address[],
  bufferArkAddress: Address,
  isCrossChain: boolean = false,
  targetChain?: string,
  hubChain?: string,
  curatorAddress?: Address,
  rewardInfo?: { tokens?: string[]; amounts?: string[]; duration?: string },
  useBummerConfig: boolean = false,
): Promise<FleetSingleChainContent | FleetCrossChainContent> {
  const sourceTitle = `SIP1.${fleetDefinition.sipNumber || 'X'}: ${isCrossChain ? 'Cross-chain ' : ''}Fleet Deployment: ${fleetDefinition.fleetName} on ${targetChain}`

  // Create curator section if curator is provided
  const curatorSection = curatorAddress ? `- Curator: ${curatorAddress}` : ''

  // Format reward information if provided
  let rewardsSection = ''
  if (rewardInfo && rewardInfo.tokens && rewardInfo.amounts && rewardInfo.duration) {
    const formattedAmounts: string[] = []

    // Format each token amount
    for (let i = 0; i < rewardInfo.tokens.length; i++) {
      const rawAmount = rewardInfo.amounts[i]
      try {
        const tokenAddress = rewardInfo.tokens[i] as Address

        // Try to get token decimals
        let decimals = 18 // Default to 18 if we can't get the actual value
        try {
          const tokenContract = await hre.viem.getContractAt(
            'IERC20Metadata' as string,
            tokenAddress,
          )
          decimals = (await tokenContract.read.decimals()) as number
        } catch (error) {
          console.log(
            kleur.yellow(`Could not get decimals for token ${tokenAddress}, using default 18`),
          )
        }

        // Calculate human-readable amount
        const amount = BigInt(rawAmount)
        const readableAmount =
          Number(amount / BigInt(10 ** Math.min(decimals, 18))) /
          (decimals > 18 ? 10 ** (decimals - 18) : 1)

        formattedAmounts.push(`${readableAmount.toLocaleString()} tokens (${rawAmount})`)
      } catch (error) {
        formattedAmounts.push(rawAmount) // Fall back to raw amount if formatting fails
      }
    }

    // Format duration
    const durationSeconds = parseInt(rewardInfo.duration)
    const durationDays = Math.round(durationSeconds / 86400) // Convert seconds to days
    const formattedDuration = `${durationDays} days (${durationSeconds} seconds)`

    rewardsSection = `
### Rewards Configuration
- Reward Tokens: ${rewardInfo.tokens.join(', ')}
- Reward Amounts: ${formattedAmounts.join(', ')}
- Rewards Duration: ${formattedDuration}`
  }

  // Format bridge amount if provided
  let bridgeSection = ''
  const bridgeAmount = fleetDefinition.bridgeAmount

  if (bridgeAmount && targetChain) {
    const targetChainConfig = getConfigByNetwork(targetChain, { gov: true }, useBummerConfig)
    try {
      // Try to format the bridge amount in a human-readable way
      const amount = BigInt(bridgeAmount)
      const readableAmount = Number(amount / BigInt(10 ** 18)) // Assuming 18 decimals

      bridgeSection = `
### Token Bridge
- Amount: ${readableAmount.toLocaleString()} tokens (${bridgeAmount} raw)
- Destination: ${_.capitalize(targetChain)} - Treasury (SummerTimelock) ${targetChainConfig.deployedContracts.gov.timelock.address}
`
    } catch (error) {
      // Fallback if parsing fails
      bridgeSection = `
### Token Bridge
- Amount: ${bridgeAmount}
- Destination: ${targetChain} Timelock
`
    }
  }

  // Format configuration values to be human-readable
  const formattedBridgeAmount = formatBridgeAmount(bridgeAmount)
  const formattedDepositCap = formatDepositCap(fleetDefinition.depositCap)
  const formattedBufferBalance = formatBufferBalance(fleetDefinition.initialMinimumBufferBalance)
  const formattedRebalanceCooldown = formatRebalanceCooldown(
    fleetDefinition.initialRebalanceCooldown,
  )
  const formattedTipRate = formatTipRate(fleetDefinition.initialTipRate)

  // Standard description for the destination chain (or single-chain proposal)
  const standardDescription = `# SIP1.${fleetDefinition.sipNumber || 'X'}: Fleet Deployment: ${fleetDefinition.fleetName}

## Summary
This proposal activates the ${fleetDefinition.fleetName} Fleet (${fleetDefinition.symbol}).

## Motivation
This fleet deployment will expand the protocol's capabilities by adding ${deployedArkAddresses.length} new Arks to the ecosystem.

## Technical Details
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}
${curatorSection}

## Specifications
### Actions
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Grant COMMANDER_ROLE to Fleet Commander for each Ark
4. Add ${deployedArkAddresses.length} Arks to the Fleet
${curatorAddress ? '5. Grant CURATOR_ROLE to Curator for the Fleet' : ''}
${rewardInfo?.tokens ? `${curatorAddress ? '6' : '5'}. Set up rewards for ${rewardInfo.tokens.length} tokens` : ''}

### Fleet Configuration
- Deposit Cap: ${formattedDepositCap}
- Initial Minimum Buffer Balance: ${formattedBufferBalance}
- Initial Rebalance Cooldown: ${formattedRebalanceCooldown}
- Initial Tip Rate: ${formattedTipRate}
${rewardsSection}`

  if (!isCrossChain) {
    return {
      title: sourceTitle,
      description: standardDescription,
      sourceTitle,
      sourceDescription: standardDescription,
    }
  }

  if (!targetChain || !hubChain) {
    throw new Error('Target chain and hub chain must be provided for cross-chain proposals')
  }

  // Destination chain description (what will be executed on the target chain)
  const destinationDescription = standardDescription

  // Source chain description (what will be shown on the hub chain)
  const sourceDescription = `# SIP1.${fleetDefinition.sipNumber || 'X'}: Cross-chain Fleet Deployment Proposal

## Summary
This is a cross-chain governance proposal to activate the ${fleetDefinition.fleetName} Fleet on ${targetChain}.

## Motivation
This cross-chain fleet deployment will expand the protocol's capabilities across multiple networks.

## Technical Details
- Hub Chain: ${hubChain}
- Target Chain: ${targetChain}
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}
${curatorSection}
${bridgeSection}

## Specifications
### Actions
This proposal will execute the following actions on ${targetChain}:
${bridgeAmount ? `1. Bridge ${formattedBridgeAmount} tokens to the target chain\n` : ''}${bridgeAmount ? '2' : '1'}. Add Fleet to Harbor Command
${bridgeAmount ? '3' : '2'}. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
${bridgeAmount ? '4' : '3'}. Add ${deployedArkAddresses.length} Arks to the Fleet
${bridgeAmount ? '5' : '4'}. Grant COMMANDER_ROLE to Fleet Commander for each Ark
${curatorAddress ? `${bridgeAmount ? '6' : '5'}. Grant CURATOR_ROLE to Curator for the Fleet` : ''}
${rewardInfo?.tokens ? `${curatorAddress ? (bridgeAmount ? '7' : '6') : bridgeAmount ? '6' : '5'}. Set up rewards for ${rewardInfo.tokens.length} tokens` : ''}

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

### Fleet Configuration
- Deposit Cap: ${formattedDepositCap}
- Initial Minimum Buffer Balance: ${formattedBufferBalance}
- Initial Rebalance Cooldown: ${formattedRebalanceCooldown}
- Initial Tip Rate: ${formattedTipRate}
${rewardsSection}
`

  return {
    title: sourceTitle,
    description: sourceDescription,
    sourceTitle,
    sourceDescription,
    destinationDescription,
  }
}

function formatBridgeAmount(bridgeAmount: string): string {
  try {
    const amount = BigInt(bridgeAmount)
    const readableAmount = Number(amount / BigInt(10 ** 18))
    return `${readableAmount.toLocaleString()} (${bridgeAmount} raw)`
  } catch (error) {
    return bridgeAmount
  }
}

/**
 * Generic formatter for token amounts with decimals
 * @param value The raw value as a string
 * @param decimals Number of decimals to apply
 * @param type Optional type identifier for special formatting
 */
function formatValue(
  value: string,
  decimals: number = 18,
  type: 'token' | 'percentage' | 'time' = 'token',
): string {
  try {
    if (type === 'time') {
      // Handle time-based values (seconds)
      const seconds = parseInt(value)
      let readableTime = ''

      if (seconds < 60) {
        readableTime = `${seconds} seconds`
      } else if (seconds < 3600) {
        const minutes = Math.floor(seconds / 60)
        readableTime = `${minutes} minute${minutes > 1 ? 's' : ''} (${seconds} seconds)`
      } else {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        readableTime = `${hours} hour${hours > 1 ? 's' : ''}${minutes > 0 ? ` ${minutes} minute${minutes > 1 ? 's' : ''}` : ''} (${seconds} seconds)`
      }

      return readableTime
    }

    const amount = BigInt(value)

    if (type === 'percentage') {
      // Handle percentage values
      const percentage = (Number(amount) / 10 ** decimals) * 100
      return `${percentage}% (${value} raw)`
    }

    // Default: handle token amounts
    const divisor = BigInt(10 ** Math.min(decimals, 18))
    const readableAmount = Number(amount / divisor) / (decimals > 18 ? 10 ** (decimals - 18) : 1)
    return `${readableAmount.toLocaleString()} (${value} raw)`
  } catch (error) {
    return value // Return original if parsing fails
  }
}

/**
 * Format deposit cap to be human-readable
 */
function formatDepositCap(depositCap: string): string {
  return formatValue(depositCap)
}

/**
 * Format buffer balance to be human-readable
 */
function formatBufferBalance(bufferBalance: string): string {
  return formatValue(bufferBalance, 6)
}

/**
 * Format rebalance cooldown to be human-readable
 */
function formatRebalanceCooldown(cooldown: string): string {
  return formatValue(cooldown, 0, 'time')
}

/**
 * Format tip rate to be human-readable
 */
function formatTipRate(tipRate: string): string {
  const tipRateNumber = BigInt(Number(tipRate))
  const tipRatePercentage = tipRateNumber / 100n // 1e18 is actually 1% with our percentages library
  return formatValue(tipRatePercentage.toString(), 18, 'percentage')
}

/**
 * Prepares proposal actions for adding arks to a fleet
 * This is a common function used by multiple proposal types
 */
export function prepareArkAdditionActions(
  fleetCommanderAddress: Address,
  arkAddresses: Address[],
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of arkAddresses) {
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, fleetCommanderAddress],
      }) as Hex,
    )
  }

  // Add each Ark to the Fleet Commander
  for (const arkAddress of arkAddresses) {
    targets.push(fleetCommanderAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for adding a fleet to Harbor Command
 */
export function prepareHarborAdditionActions(
  fleetCommanderAddress: Address,
  harborCommandAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [harborCommandAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [fleetCommanderAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for granting commander role for BufferArk
 */
export function prepareBufferArkActions(
  bufferArkAddress: Address,
  fleetCommanderAddress: Address,
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [protocolAccessManagerAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, fleetCommanderAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for granting curator role
 */
export function prepareCuratorActions(
  fleetCommanderAddress: Address,
  curatorAddress: Address,
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [protocolAccessManagerAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function grantCuratorRole(address fleetAddress, address account) external']),
      args: [fleetCommanderAddress, curatorAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Prepares actions to set up fleet rewards
 */
export async function prepareRewardSetupActions(
  rewardsManagerAddress: Address,
  rewardTokens: Address[],
  rewardAmounts: bigint[],
  rewardsDurations: number[],
  timelock: Address,
  summerTokenAddress: Address,
  publicClient: PublicClient,
): Promise<{ targets: Address[]; values: bigint[]; calldatas: Hex[] }> {
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  console.log(kleur.yellow('Checking if timelock is whitelisted as a rewarder'))
  console.log(kleur.yellow('Timelock:'), timelock)
  console.log(kleur.yellow('Summer token address:'), summerTokenAddress)
  // Add action to whitelist timelock as a rewarder if provided
  const isTimelockWhitelisted = await publicClient.readContract({
    address: summerTokenAddress,
    abi: SummerTokenABI.abi,
    functionName: 'whitelistedAddresses',
    args: [timelock],
  })
  console.log(kleur.yellow('Is timelock whitelisted:'), isTimelockWhitelisted)

  if (!isTimelockWhitelisted) {
    console.log(kleur.yellow('Timelock is not whitelisted as a rewarder, adding to whitelist'))
    targets.push(summerTokenAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: SummerTokenABI.abi,
        functionName: 'addToWhitelist',
        args: [timelock],
      }) as Hex,
    )
  }

  console.log(kleur.yellow('Whitelisting rewards manager as a rewarder'))
  targets.push(summerTokenAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: SummerTokenABI.abi,
      functionName: 'addToWhitelist',
      args: [rewardsManagerAddress],
    }) as Hex,
  )

  for (let i = 0; i < rewardTokens.length; i++) {
    // Add action to approve token transfer to rewards manager
    targets.push(rewardTokens[i])
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function approve(address spender, uint256 amount) external returns (bool)',
        ]),
        args: [rewardsManagerAddress, rewardAmounts[i]],
      }) as Hex,
    )

    // Add action to notify reward amount
    targets.push(rewardsManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
        ]),
        args: [rewardTokens[i], rewardAmounts[i], BigInt(rewardsDurations[i])],
      }) as Hex,
    )
  }

  return { targets, values, calldatas }
}

/**
 * Creates a governance proposal that only adds arks to an existing fleet
 */
export async function createArkAdditionProposal(
  fleetCommanderAddress: Address,
  arkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan('Creating governance proposal to add arks to existing fleet'))

  // Use the correct governor address from the config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Get the actions for adding arks
  const { targets, values, calldatas } = prepareArkAdditionActions(
    fleetCommanderAddress,
    arkAddresses,
    protocolAccessManagerAddress,
  )

  // Format ark addresses for display in proposal
  const arkAddressList = arkAddresses.map((addr, i) => `${i + 1}. \`${addr}\``).join('\n')

  // Create simplified proposal title and description with SIP2 prefix for ARK management
  const isMultiple = arkAddresses.length > 1
  const title = `SIP2.${fleetDefinition.sipNumber || 'X'}: Add ${arkAddresses.length} ${isMultiple ? 'Arks' : 'Ark'} to ${fleetDefinition.fleetName} Fleet`
  const description = `# SIP2.${fleetDefinition.sipNumber || 'X'}: Add ${isMultiple ? 'Arks' : 'Ark'} to ${fleetDefinition.fleetName} Fleet

## Summary
This proposal adds ${arkAddresses.length} new ${isMultiple ? 'Ark(s)' : 'Ark'} to the existing ${fleetDefinition.fleetName} Fleet.

## New ${isMultiple ? 'Ark Addresses' : 'Ark Address'}
${arkAddressList}

## Actions
1. Grant COMMANDER_ROLE to Fleet Commander for ${isMultiple ? 'each Ark' : 'the Ark'}
2. Add ${isMultiple ? 'each Ark' : 'the Ark'} to the Fleet Commander

## References
${fleetDefinition.discourseURL ? `Discourse: ${fleetDefinition.discourseURL}` : ''}
`

  // Generate proposal details
  const chainId = HUB_CHAIN_ID

  // Get the discourse URL from the fleet definition if available
  const discourseURL = fleetDefinition.discourseURL || ''
  if (discourseURL) {
    console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
  }

  // Convert targets, values, and calldatas into ProposalAction array
  const actions = targets.map((target, index) => ({
    target,
    value: values[index],
    calldata: calldatas[index],
  }))

  // Generate a save path for the proposal JSON
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const networkName = hre.network.name
  const savePath = path.join(
    process.cwd(),
    '/proposals',
    `${networkName}_proposal_${timestamp}.json`,
  )

  // Submit proposal
  await createGovernanceProposal(
    title,
    description,
    actions,
    governorAddress,
    chainId,
    discourseURL,
    [],
    savePath,
  )
}

/**
 * Creates a governance proposal on the hub chain and optionally submits a draft to Tally
 */
export async function createHubGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
  curatorAddress?: Address,
) {
  // Use the correct governor address from the config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  const harborCommandAddress = config.deployedContracts.core.harborCommand.address as Address
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Prepare the proposal targets, values, and calldatas
  let targets: Address[] = []
  let values: bigint[] = []
  let calldatas: Hex[] = []

  // 1. Add Fleet to Harbor Command
  const harborActions = prepareHarborAdditionActions(
    deployedFleet.fleetCommander.address,
    harborCommandAddress,
  )
  targets = [...targets, ...harborActions.targets]
  values = [...values, ...harborActions.values]
  calldatas = [...calldatas, ...harborActions.calldatas]

  // 2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  const bufferArkActions = prepareBufferArkActions(
    bufferArkAddress,
    deployedFleet.fleetCommander.address,
    protocolAccessManagerAddress,
  )
  targets = [...targets, ...bufferArkActions.targets]
  values = [...values, ...bufferArkActions.values]
  calldatas = [...calldatas, ...bufferArkActions.calldatas]

  // 3. Add Arks and grant COMMANDER_ROLE
  const arkActions = prepareArkAdditionActions(
    deployedFleet.fleetCommander.address,
    deployedArkAddresses,
    protocolAccessManagerAddress,
  )
  targets = [...targets, ...arkActions.targets]
  values = [...values, ...arkActions.values]
  calldatas = [...calldatas, ...arkActions.calldatas]

  // 4. Grant CURATOR_ROLE if provided
  if (curatorAddress) {
    const curatorActions = prepareCuratorActions(
      deployedFleet.fleetCommander.address,
      curatorAddress,
      protocolAccessManagerAddress,
    )
    targets = [...targets, ...curatorActions.targets]
    values = [...values, ...curatorActions.values]
    calldatas = [...calldatas, ...curatorActions.calldatas]
  }

  // 5. Add reward setup actions if rewards are specified
  if (
    fleetDefinition.rewardTokens &&
    fleetDefinition.rewardAmounts &&
    fleetDefinition.rewardsDuration
  ) {
    try {
      const rewardsManagerAddress = await getRewardsManagerAddress(
        deployedFleet.fleetCommander.address,
      )

      const rewardActions = await prepareRewardSetupActions(
        rewardsManagerAddress,
        fleetDefinition.rewardTokens.map((token) => token as Address),
        fleetDefinition.rewardAmounts.map((amount) => BigInt(amount)),
        Array(fleetDefinition.rewardTokens.length).fill(fleetDefinition.rewardsDuration),
        config.deployedContracts.gov.timelock.address as Address,
        config.deployedContracts.gov.summerToken.address as Address,
        await hre.viem.getPublicClient(),
      )

      targets = [...targets, ...rewardActions.targets]
      values = [...values, ...rewardActions.values]
      calldatas = [...calldatas, ...rewardActions.calldatas]

      console.log(
        kleur.yellow(`- Set up rewards for ${fleetDefinition.rewardTokens.length} tokens`),
      )
    } catch (error: unknown) {
      console.error(
        kleur.red(
          `Error preparing reward setup actions: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
    }
  }

  // Replace the try/catch block with common submission logic
  try {
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))
    if (curatorAddress) {
      console.log(kleur.yellow(`- Grant CURATOR_ROLE to ${curatorAddress} for the fleet`))
    }
    if (fleetDefinition.rewardTokens) {
      console.log(
        kleur.yellow(`- Set up rewards for ${fleetDefinition.rewardTokens.length} tokens`),
      )
    }

    const proposalContent = await generateFleetProposalDescription(
      deployedFleet,
      fleetDefinition,
      deployedArkAddresses,
      bufferArkAddress,
      false, // isCrossChain
      HUB_CHAIN_NAME, // targetChain (will be overridden)
      HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
      curatorAddress, // Add curator address
      fleetDefinition.rewardTokens
        ? {
            // Add reward info if available
            tokens: fleetDefinition.rewardTokens,
            amounts: fleetDefinition.rewardAmounts,
            duration: fleetDefinition.rewardsDuration?.toString(),
          }
        : undefined,
      useBummerConfig,
    )

    // Generate proposal details
    const title = proposalContent.sourceTitle
    const description = proposalContent.sourceDescription
    const chainId = HUB_CHAIN_ID

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = targets.map((target, index) => ({
      target,
      value: values[index],
      calldata: calldatas[index],
    }))

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const networkName = hre.network.name
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `${networkName}_proposal_${timestamp}.json`,
    )

    // Submit the proposal directly
    await createGovernanceProposal(
      title,
      description,
      actions,
      governorAddress,
      chainId,
      discourseURL,
      [],
      savePath,
    )

    console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
  } catch (error: any) {
    console.error(kleur.red('Error creating proposal:'), error)
  }
}

/**
 * Creates a cross-chain governance proposal from the hub chain to a satellite chain
 */
export async function createSatelliteGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  targetChainConfig: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
  isTenderlyVirtualTestnet: boolean,
  curatorAddress?: Address,
) {
  console.log(kleur.yellow('Creating cross-chain governance proposal...'))

  // Prepare bridge actions with the new helper function
  const result = await getChainConfigByChainId(HUB_CHAIN_ID)
  if (!result) throw new Error(`No chain config found for chain ID ${HUB_CHAIN_ID}`)
  const { publicClient: hubChainPublicClient } = await createClients(
    result.chainConfig.chain,
    result.chainConfig.rpcUrl,
    process.env.DEPLOYER_PRIV_KEY as Address,
  )
  const targetChainPublicClient = await hre.viem.getPublicClient()

  const hubConfig = getConfigByNetwork(HUB_CHAIN_NAME, { gov: true, core: true }, useBummerConfig)

  // 2. Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  console.log(
    kleur.blue('Using config:'),
    useBummerConfig ? kleur.cyan('Bummer/Test') : kleur.cyan('Production'),
  )

  // Get current chain's endpoint ID
  const currentChainEndpointId = targetChainConfig.common.layerZero.eID

  // 3. Prepare the destination (satellite) proposal
  const dstTargets: Address[] = []
  const dstValues: bigint[] = []
  const dstCalldatas: Hex[] = []

  // 3.1 Add Fleet to Harbor Command
  const harborCommandAddress = targetChainConfig.deployedContracts.core.harborCommand
    .address as Address
  dstTargets.push(harborCommandAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.2 Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  const protocolAccessManagerAddress = targetChainConfig.deployedContracts.gov.protocolAccessManager
    .address as Address

  dstTargets.push(protocolAccessManagerAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.3 & 3.4 Add Arks and grant COMMANDER_ROLE
  const arkActions = prepareArkAdditionActions(
    deployedFleet.fleetCommander.address,
    deployedArkAddresses,
    protocolAccessManagerAddress,
  )
  dstTargets.push(...arkActions.targets)
  dstValues.push(...arkActions.values)
  dstCalldatas.push(...arkActions.calldatas)

  // 3.5 Grant CURATOR_ROLE to the curator for the fleet if provided
  if (curatorAddress) {
    dstTargets.push(protocolAccessManagerAddress)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCuratorRole(address fleetAddress, address account) external',
        ]),
        args: [deployedFleet.fleetCommander.address, curatorAddress],
      }) as Hex,
    )
  }

  // 3.6 Add reward setup actions if rewards are specified
  if (
    fleetDefinition.rewardTokens &&
    fleetDefinition.rewardAmounts &&
    fleetDefinition.rewardsDuration
  ) {
    try {
      const rewardsManagerAddress = await getRewardsManagerAddress(
        deployedFleet.fleetCommander.address,
      )

      const rewardActions = await prepareRewardSetupActions(
        rewardsManagerAddress,
        fleetDefinition.rewardTokens.map((token) => token as Address),
        fleetDefinition.rewardAmounts.map((amount) => BigInt(amount)),
        Array(fleetDefinition.rewardTokens.length).fill(fleetDefinition.rewardsDuration),
        targetChainConfig.deployedContracts.gov.timelock.address as Address,
        targetChainConfig.deployedContracts.gov.summerToken.address as Address,
        targetChainPublicClient,
      )

      dstTargets.push(...rewardActions.targets)
      dstValues.push(...rewardActions.values)
      dstCalldatas.push(...rewardActions.calldatas)

      console.log(
        kleur.yellow(`- Set up rewards for ${fleetDefinition.rewardTokens.length} tokens`),
      )
    } catch (error: unknown) {
      console.error(
        kleur.red(
          `Error preparing reward setup actions: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
    }
  }

  const proposalDescriptions = (await generateFleetProposalDescription(
    deployedFleet,
    fleetDefinition,
    deployedArkAddresses,
    bufferArkAddress,
    true, // isCrossChain
    hre.network.name, // targetChain
    HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
    curatorAddress, // Add curator address
    fleetDefinition.rewardTokens
      ? {
          tokens: fleetDefinition.rewardTokens,
          amounts: fleetDefinition.rewardAmounts,
          duration: fleetDefinition.rewardsDuration?.toString(),
        }
      : undefined,
  )) as FleetCrossChainContent

  const dstDescription = proposalDescriptions.destinationDescription
  const srcDescription = proposalDescriptions.sourceDescription
  const title = proposalDescriptions.sourceTitle

  // 4. Prepare the source (hub) proposal
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const HUB_TIMELOCK_ADDRESS = hubConfig.deployedContracts.gov.timelock.address as Address
  console.log(kleur.blue('Using hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

  const srcTargets: Address[] = []
  const srcValues: bigint[] = []
  const srcCalldatas: Hex[] = []

  // 4.1 Add bridge transactions if rewards are specified
  if (fleetDefinition.bridgeAmount) {
    try {
      console.log(kleur.yellow('Adding token bridge actions for rewards...'))

      // Get the bridge contract address from the hub config
      const bridgeContractAddress = hubConfig.deployedContracts.gov.summerToken.address as Address
      if (!bridgeContractAddress) {
        throw new Error('Bridge contract address not found in hub config')
      }

      // Get the timelock address for the target chain
      const targetTimelockAddress = targetChainConfig.deployedContracts.gov.timelock
        .address as Address

      const {
        targets: bridgeTargets,
        values: bridgeValues,
        calldatas: bridgeCalldatas,
      } = await prepareBridgeTransaction(
        bridgeContractAddress,
        BigInt(fleetDefinition.bridgeAmount),
        Number(currentChainEndpointId),
        targetTimelockAddress,
        HUB_TIMELOCK_ADDRESS,
        hubChainPublicClient,
      )

      // Add the bridge actions to the source chain proposal
      srcTargets.push(...bridgeTargets)
      srcValues.push(...bridgeValues)
      srcCalldatas.push(...bridgeCalldatas)

      console.log(kleur.green(`- Added aggregated bridge transactions for rewards`))
    } catch (error: unknown) {
      console.error(
        kleur.red(
          `Error preparing bridge actions: ${error instanceof Error ? error.message : String(error)}`,
        ),
      )
    }
  }

  // 4.2 Add the cross-chain proposal action
  const ESTIMATED_GAS = 400000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  srcTargets.push(HUB_GOVERNOR_ADDRESS)
  srcValues.push(0n)
  srcCalldatas.push(
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(currentChainEndpointId),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  )

  // 5. Create proposal using createGovernanceProposal directly
  try {
    console.log(kleur.cyan('Creating cross-chain governance proposal with the following actions:'))
    if (fleetDefinition.rewardTokens) {
      console.log(kleur.yellow(`- Bridge reward tokens to target chain timelock`))
    }
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))
    if (curatorAddress) {
      console.log(kleur.yellow(`- Grant CURATOR_ROLE to ${curatorAddress} for the fleet`))
    }
    if (fleetDefinition.rewardTokens) {
      console.log(
        kleur.yellow(`- Set up rewards for ${fleetDefinition.rewardTokens.length} tokens`),
      )
      console.log(kleur.yellow('- Whitelisting rewards manager as a rewarder'))
    }

    // Generate proposal details
    const chainId = HUB_CHAIN_ID

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''

    // Create action summary for better display in proposal
    const actionSummary = [
      fleetDefinition.rewardTokens
        ? `Bridge aggregated reward tokens to ${hre.network.name} timelock`
        : '',
      fleetDefinition.bridgeAmount
        ? `Bridge ${fleetDefinition.bridgeAmount} to ${hre.network.name} timelock`
        : '',
      `Send cross-chain proposal to ${hre.network.name}`,
      `Execute ${dstTargets.length} actions on the destination chain`,
    ].filter(Boolean)

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const networkName = hre.network.name
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `${networkName}_proposal_${timestamp}.json`,
    )

    // Add cross-chain execution details
    const crossChainExecution = {
      hubChain: {
        name: HUB_CHAIN_NAME,
        chainId: HUB_CHAIN_ID,
        governorAddress: HUB_GOVERNOR_ADDRESS,
      },
      targetChain: {
        name: hre.network.name,
        chainId: hre.network.config.chainId || 0,
        targets: dstTargets.map((t) => t.toString()),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c.toString()),
      },
    }

    // Submit proposal using createGovernanceProposal directly
    await createGovernanceProposal(
      title,
      srcDescription,
      actions,
      HUB_GOVERNOR_ADDRESS,
      chainId,
      discourseURL,
      actionSummary,
      savePath,
      crossChainExecution,
    )

    console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
  } catch (error: any) {
    console.error(kleur.red('Error creating cross-chain proposal:'), error)
  }
}

/**
 * Creates a cross-chain governance proposal to add arks to an existing fleet on a satellite chain
 */
export async function createArkAdditionCrossChainProposal(
  fleetCommanderAddress: Address,
  arkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
  isTenderlyVirtualTestnet: boolean,
): Promise<void> {
  console.log(kleur.yellow('Creating cross-chain governance proposal to add arks...'))

  const hubConfig = getConfigByNetwork(HUB_CHAIN_NAME, { gov: true, core: true }, useBummerConfig)

  // Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  console.log(
    kleur.blue('Using config:'),
    useBummerConfig ? kleur.cyan('Bummer/Test') : kleur.cyan('Production'),
  )

  // Get current chain's endpoint ID
  const currentChainEndpointId = config.common.layerZero.eID

  // Prepare the destination (satellite) proposal actions
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Get the actions for adding arks
  const {
    targets: dstTargets,
    values: dstValues,
    calldatas: dstCalldatas,
  } = prepareArkAdditionActions(fleetCommanderAddress, arkAddresses, protocolAccessManagerAddress)

  // Format ark addresses for display in proposal
  const arkAddressList = arkAddresses.map((addr, i) => `${i + 1}. \`${addr}\``).join('\n')

  // Determine singular or plural based on number of arks
  const isMultiple = arkAddresses.length > 1

  // Create proposal title and descriptions
  const title = `SIP2.${fleetDefinition.sipNumber || 'X'}: Add ${arkAddresses.length} ${isMultiple ? 'Arks' : 'Ark'} to ${fleetDefinition.fleetName} Fleet on ${hre.network.name}`

  // Destination chain description (what will be executed on the satellite chain)
  const dstDescription = `# Add ${isMultiple ? 'Arks' : 'Ark'} to ${fleetDefinition.fleetName} Fleet

## Summary
This proposal adds ${arkAddresses.length} new ${isMultiple ? 'Ark(s)' : 'Ark'} to the existing ${fleetDefinition.fleetName} Fleet on ${hre.network.name}.

## New ${isMultiple ? 'Ark Addresses' : 'Ark Address'}
${arkAddressList}

## Actions
1. Grant COMMANDER_ROLE to Fleet Commander for ${isMultiple ? 'each Ark' : 'the Ark'}
2. Add ${isMultiple ? 'each Ark' : 'the Ark'} to the Fleet Commander

## References
${fleetDefinition.discourseURL ? `Discourse: ${fleetDefinition.discourseURL}` : ''}
`

  // Source chain description (what will be shown on the hub chain)
  const srcDescription = `# Cross-chain Proposal: Add ${isMultiple ? 'Arks' : 'Ark'} to ${fleetDefinition.fleetName} Fleet

## Summary
This is a cross-chain governance proposal to add ${arkAddresses.length} new ${isMultiple ? 'Ark(s)' : 'Ark'} to the existing ${fleetDefinition.fleetName} Fleet on ${hre.network.name}.

## Motivation
Expanding this fleet with additional ${isMultiple ? 'Arks' : 'an Ark'} will enhance the protocol's capabilities on ${hre.network.name}.

## Technical Details
- Hub Chain: ${HUB_CHAIN_NAME}${useBummerConfig ? ' (Bummer)' : ' (Production)'}
- Target Chain: ${hre.network.name}
- Fleet Commander: ${fleetCommanderAddress}
- Number of ${isMultiple ? 'Arks' : 'Ark'} to add: ${arkAddresses.length}

## New ${isMultiple ? 'Ark Addresses' : 'Ark Address'}
${arkAddressList}

## Specifications
### Actions
This proposal will execute the following actions on ${hre.network.name}:
1. Grant COMMANDER_ROLE to Fleet Commander for ${isMultiple ? 'each Ark' : 'the Ark'}
2. Add ${isMultiple ? 'each Ark' : 'the Ark'} to the Fleet Commander

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

## References
${fleetDefinition.discourseURL ? `Discourse: ${fleetDefinition.discourseURL}` : ''}
`

  // Prepare the source (hub) proposal
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  console.log(kleur.blue('Using hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const ESTIMATED_GAS = 400000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(currentChainEndpointId),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  // Replace the Tally-specific code with createGovernanceProposal
  try {
    console.log(kleur.cyan('Creating cross-chain governance proposal to add arks'))
    console.log(kleur.blue('Hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

    // Generate proposal details
    const chainId = HUB_CHAIN_ID

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''
    if (discourseURL) {
      console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
    }

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const networkName = hre.network.name
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `${networkName}_proposal_${timestamp}.json`,
    )

    // Add cross-chain execution details
    const crossChainExecution = [
      {
        name: hre.network.name,
        chainId: hre.network.config.chainId || 0,
        targets: dstTargets.map((t) => t.toString()),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c.toString()),
      },
    ]

    // Submit proposal using createGovernanceProposal directly
    await createGovernanceProposal(
      title,
      srcDescription,
      actions,
      HUB_GOVERNOR_ADDRESS,
      chainId,
      discourseURL,
      [],
      savePath,
      crossChainExecution,
    )

    console.log(kleur.yellow('The arks will be added once this proposal is executed.'))
  } catch (error: any) {
    console.error(kleur.red('Error creating cross-chain proposal:'), error)
  }
}
