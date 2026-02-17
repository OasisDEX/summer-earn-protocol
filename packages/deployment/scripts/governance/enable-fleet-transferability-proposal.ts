import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { promptForChain } from '../helpers/chain-prompt'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

const harborCommandAbi = parseAbi([
  'function getActiveFleetCommanders() external view returns (address[])',
])

// Target chains for the multi-chain proposal
const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet', 'sonic']

interface ChainFleetCommanders {
  chainName: string
  harborCommandAddress: string
  fleetCommanders: string[]
}

async function main() {
  // Get hub chain configuration through prompt
  const {
    config: hubConfig,
    chain,
    rpcUrl,
    name: hubChainName,
  } = await promptForChain('Select the hub chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get the governor address
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.govV2.summerGovernor.address as Address

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Prepare actions for the hub chain
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // Store cross-chain execution details for the proposal data
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    // Store fleet commanders info for all chains
    const allChainFleetCommanders: ChainFleetCommanders[] = []

    // Process hub chain first
    console.log(kleur.yellow('Getting fleet commanders for hub chain...'))
    const hubHarborCommandAddress = hubConfig.deployedContracts.core.harborCommand
      .address as Address

    const hubFleetCommanders = (await publicClient.readContract({
      address: hubHarborCommandAddress,
      abi: harborCommandAbi,
      functionName: 'getActiveFleetCommanders',
    })) as Address[]

    allChainFleetCommanders.push({
      chainName: HUB_CHAIN_NAME,
      harborCommandAddress: hubHarborCommandAddress,
      fleetCommanders: hubFleetCommanders,
    })

    console.log(
      kleur.green(`Found ${hubFleetCommanders.length} fleet commanders on ${HUB_CHAIN_NAME}`),
    )

    // Add hub chain actions
    for (const fleetCommander of hubFleetCommanders) {
      srcTargets.push(fleetCommander)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: parseAbi(['function setFleetTokenTransferability() external']),
          functionName: 'setFleetTokenTransferability',
          args: [],
        }),
      )
    }

    // Process satellite chains
    console.log(kleur.yellow('Getting fleet commanders for satellite chains...'))
    for (const chainName of TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)) {
      const chainConfig = await promptForChain(`Select the ${chainName} chain configuration:`)
      const { publicClient: chainPublicClient } = createClients(
        chainConfig.chain,
        chainConfig.rpcUrl,
      )

      const harborCommandAddress = chainConfig.config.deployedContracts.core.harborCommand
        .address as Address

      const fleetCommanders = (await chainPublicClient.readContract({
        address: harborCommandAddress,
        abi: harborCommandAbi,
        functionName: 'getActiveFleetCommanders',
      })) as Address[]

      allChainFleetCommanders.push({
        chainName,
        harborCommandAddress,
        fleetCommanders,
      })

      console.log(kleur.green(`Found ${fleetCommanders.length} fleet commanders on ${chainName}`))

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      for (const fleetCommander of fleetCommanders) {
        dstTargets.push(fleetCommander)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: parseAbi(['function setFleetTokenTransferability() external']),
            functionName: 'setFleetTokenTransferability',
            args: [],
          }),
        )
      }

      // Store cross-chain execution data for this chain
      crossChainExecutions.push({
        name: chainName,
        chainId: Number(getChainIdByNetwork(chainName)),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      })

      // Create destination chain description
      const dstDescription = `
# Enable Fleet Token Transferability on ${chainName}

## Summary
This cross-chain proposal enables token transferability for all active fleet commanders on ${chainName}.

## Actions
${fleetCommanders
  .map(
    (commander, index) => `
    ${index + 1}. Enable token transferability for fleet commander ${commander}`,
  )
  .join('\n')}
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 200000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(HUB_GOVERNOR_ADDRESS)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: parseAbi([
            'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
          ]),
          functionName: 'sendProposalToTargetChain',
          args: [
            Number(chainConfig.config.common.layerZero.eID),
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            lzOptions,
          ],
        }),
      )

      console.log(kleur.green(`- Added cross-chain proposal for ${chainName}`))
    }

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP6.${sipMinorNumber}` : 'SIP6'
    const title = `${sipNumber}: Multi-Chain Fleet Token Transferability Enablement`

    // Create detailed description
    const description = `
# ${sipNumber}: Multi-Chain Fleet Token Transferability Enablement

## Summary
This proposal enables token transferability for all active fleet commanders across all active chains in the Lazy Summer Protocol ecosystem.

## Motivation
Fleet commanders currently have token transfers disabled by default. This proposal enables token transferability to allow for proper token movement and liquidity management across the protocol.

## Specifications

### Actions
${allChainFleetCommanders
  .map(
    (chainData) => `
#### ${chainData.chainName}:
${chainData.fleetCommanders
  .map((commander, index) => `- Enable token transferability for fleet commander ${commander}`)
  .join('\n')}`,
  )
  .join('\n')}

## Technical Details
The proposal calls \`setFleetTokenTransferability()\` on each active fleet commander contract across all chains. This function enables token transfers for the respective fleet's token contract.

## Fleet Commanders Found:
${allChainFleetCommanders
  .map(
    (chainData) => `
### ${chainData.chainName} (${chainData.fleetCommanders.length} fleet commanders):
${chainData.fleetCommanders.map((commander) => `- ${commander}`).join('\n')}`,
  )
  .join('\n')}
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Enable token transferability for ${allChainFleetCommanders.find((c) => c.chainName === HUB_CHAIN_NAME)?.fleetCommanders.length || 0} fleet commanders on ${HUB_CHAIN_NAME}`,
      ...TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME).map((chain) => {
        const chainData = allChainFleetCommanders.find((c) => c.chainName === chain)
        return `Send cross-chain proposal to ${chain} (${chainData?.fleetCommanders.length || 0} fleet commanders)`
      }),
    ]

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `fleet_transferability_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    actionSummary.forEach((action) => {
      console.log(kleur.yellow(`- ${action}`))
    })

    // Use createGovernanceProposal to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      HUB_GOVERNOR_ADDRESS,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions,
    )

    console.log(
      kleur.green('✅ Successfully created multi-chain fleet transferability governance proposal'),
    )
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
      ),
    )

    // Print summary of what was found
    console.log(kleur.cyan('\n📊 Summary of Fleet Commanders Found:'))
    allChainFleetCommanders.forEach((chainData) => {
      console.log(
        kleur.white(
          `- ${chainData.chainName}: ${chainData.fleetCommanders.length} fleet commanders`,
        ),
      )
    })
  } catch (error) {
    console.error(kleur.red('Error creating multi-chain governance proposal:'), error)
    throw error
  }
}

main().catch(console.error)
