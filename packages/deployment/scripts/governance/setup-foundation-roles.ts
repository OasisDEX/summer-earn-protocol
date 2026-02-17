import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import { BaseConfig } from '../../types/config-types'
import {
  CANCELLER_ROLE,
  EXECUTOR_ROLE,
  HUB_CHAIN_ID,
  HUB_CHAIN_NAME,
  PROPOSER_ROLE,
} from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { createGovernanceProposal } from '../helpers/proposal-helpers'

// Target chains for the multi-chain proposal
const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet', 'sonic']

// DEFAULT_ADMIN_ROLE from OpenZeppelin AccessControl (bytes32(0))
const DEFAULT_ADMIN_ROLE =
  '0x0000000000000000000000000000000000000000000000000000000000000000' as Hex

/**
 * Creates a multi-chain governance proposal to grant foundation roles to the Foundation multisig.
 * This includes:
 * - GOVERNOR_ROLE in ProtocolAccessManager
 * - PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE, and DEFAULT_ADMIN_ROLE in SummerTimelockController
 */
async function setupFoundationRoles() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Verify we're on the hub chain
  if (network !== HUB_CHAIN_NAME) {
    console.log(
      kleur.red(
        `This script must be run on ${HUB_CHAIN_NAME} to create the multi-chain governance proposal.`,
      ),
    )
    return
  }

  // Get Foundation multisig address from environment
  const foundationMultisigAddress = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisigAddress) {
    console.log(kleur.red('FOUNDATION_MULTISIG_ADDRESS environment variable is not set.'))
    return
  }

  // Validate address format
  if (!/^0x[a-fA-F0-9]{40}$/.test(foundationMultisigAddress)) {
    console.log(kleur.red('FOUNDATION_MULTISIG_ADDRESS is not a valid address.'))
    return
  }

  const foundationAddress = foundationMultisigAddress as Address
  console.log(kleur.cyan('Foundation Multisig Address:'), kleur.yellow(foundationAddress))

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Helper function to filter chains based on bummer config
  const filterTargetChains = (chainName: string) => {
    if (chainName === HUB_CHAIN_NAME) return false
    if (useBummerConfig && chainName === 'mainnet') return false
    return true
  }

  // Load the configuration for the hub chain (Base)
  const hubConfig = getConfigByNetwork(
    HUB_CHAIN_NAME,
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  // Load configurations for satellite chains
  const satelliteConfigs: Record<string, BaseConfig> = {}
  for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
    satelliteConfigs[chain] = getConfigByNetwork(
      chain,
      { common: true, core: true, gov: true },
      useBummerConfig,
    ) as BaseConfig
  }

  // Display chains being targeted based on bummer config
  const effectiveTargetChains = useBummerConfig
    ? TARGET_CHAINS.filter((chain) => chain !== 'mainnet')
    : TARGET_CHAINS

  // Confirm network selection
  const confirmNetworks = await prompts({
    type: 'confirm',
    name: 'continue',
    message: `This will create a multi-chain governance proposal to grant foundation roles to ${foundationAddress} on: ${effectiveTargetChains.join(
      ', ',
    )}. Continue?`,
    initial: true,
  })

  if (!confirmNetworks.continue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Create and save the multi-chain governance proposal
  await createMultiChainFoundationRolesProposal(
    foundationAddress,
    hubConfig,
    satelliteConfigs,
    useBummerConfig,
  )
}

/**
 * Creates a multi-chain governance proposal for granting foundation roles to the Foundation multisig.
 */
async function createMultiChainFoundationRolesProposal(
  foundationAddress: Address,
  hubConfig: BaseConfig,
  satelliteConfigs: Record<string, BaseConfig>,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan().bold('\nCreating multi-chain governance proposal...'))

  // Helper function to filter chains based on bummer config
  const filterTargetChains = (chainName: string) => {
    if (chainName === HUB_CHAIN_NAME) return false
    if (useBummerConfig && chainName === 'mainnet') return false
    return true
  }

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Get the hub chain governor address
    const hubGovernorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address

    // Prepare actions for the hub chain (Base)
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // 1. Prepare hub chain actions (Base)
    console.log(kleur.yellow('Preparing hub chain actions for Base...'))

    const baseProtocolAccessManagerAddress = hubConfig.deployedContracts.gov.protocolAccessManager
      .address as Address
    const baseTimelockAddress = hubConfig.deployedContracts.gov.timelock.address as Address

    // Grant GOVERNOR_ROLE in ProtocolAccessManager
    srcTargets.push(baseProtocolAccessManagerAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'grantGovernorRole',
            type: 'function',
            inputs: [{ name: 'account', type: 'address' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'grantGovernorRole',
        args: [foundationAddress],
      }),
    )

    // Grant PROPOSER_ROLE in TimelockController
    srcTargets.push(baseTimelockAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'grantRole',
            type: 'function',
            inputs: [
              { name: 'role', type: 'bytes32' },
              { name: 'account', type: 'address' },
            ],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'grantRole',
        args: [PROPOSER_ROLE, foundationAddress],
      }),
    )

    // Grant EXECUTOR_ROLE in TimelockController
    srcTargets.push(baseTimelockAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'grantRole',
            type: 'function',
            inputs: [
              { name: 'role', type: 'bytes32' },
              { name: 'account', type: 'address' },
            ],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'grantRole',
        args: [EXECUTOR_ROLE, foundationAddress],
      }),
    )

    // Grant CANCELLER_ROLE in TimelockController
    srcTargets.push(baseTimelockAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'grantRole',
            type: 'function',
            inputs: [
              { name: 'role', type: 'bytes32' },
              { name: 'account', type: 'address' },
            ],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'grantRole',
        args: [CANCELLER_ROLE, foundationAddress],
      }),
    )

    // Grant DEFAULT_ADMIN_ROLE in TimelockController
    srcTargets.push(baseTimelockAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: [
          {
            name: 'grantRole',
            type: 'function',
            inputs: [
              { name: 'role', type: 'bytes32' },
              { name: 'account', type: 'address' },
            ],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ],
        functionName: 'grantRole',
        args: [DEFAULT_ADMIN_ROLE, foundationAddress],
      }),
    )

    // Store cross-chain execution details for the proposal data
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    // 2. Prepare cross-chain actions for each satellite chain
    console.log(kleur.yellow('Preparing cross-chain actions for satellite chains...'))
    for (const chainName of TARGET_CHAINS.filter(filterTargetChains)) {
      const satelliteConfig = satelliteConfigs[chainName]
      const protocolAccessManagerAddress = satelliteConfig.deployedContracts.gov
        .protocolAccessManager.address as Address
      const timelockAddress = satelliteConfig.deployedContracts.gov.timelock.address as Address
      const currentChainEndpointId = satelliteConfig.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainName)

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      // Grant GOVERNOR_ROLE in ProtocolAccessManager
      dstTargets.push(protocolAccessManagerAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'grantGovernorRole',
              type: 'function',
              inputs: [{ name: 'account', type: 'address' }],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'grantGovernorRole',
          args: [foundationAddress],
        }),
      )

      // Grant PROPOSER_ROLE in TimelockController
      dstTargets.push(timelockAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'grantRole',
              type: 'function',
              inputs: [
                { name: 'role', type: 'bytes32' },
                { name: 'account', type: 'address' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'grantRole',
          args: [PROPOSER_ROLE, foundationAddress],
        }),
      )

      // Grant EXECUTOR_ROLE in TimelockController
      dstTargets.push(timelockAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'grantRole',
              type: 'function',
              inputs: [
                { name: 'role', type: 'bytes32' },
                { name: 'account', type: 'address' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'grantRole',
          args: [EXECUTOR_ROLE, foundationAddress],
        }),
      )

      // Grant CANCELLER_ROLE in TimelockController
      dstTargets.push(timelockAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'grantRole',
              type: 'function',
              inputs: [
                { name: 'role', type: 'bytes32' },
                { name: 'account', type: 'address' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'grantRole',
          args: [CANCELLER_ROLE, foundationAddress],
        }),
      )

      // Grant DEFAULT_ADMIN_ROLE in TimelockController
      dstTargets.push(timelockAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'grantRole',
              type: 'function',
              inputs: [
                { name: 'role', type: 'bytes32' },
                { name: 'account', type: 'address' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'grantRole',
          args: [DEFAULT_ADMIN_ROLE, foundationAddress],
        }),
      )

      // Store cross-chain execution data for this chain
      crossChainExecutions.push({
        name: chainName,
        chainId: Number(chainId),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      })

      // Create destination chain description
      const dstDescription = `
# Foundation Roles Grant on ${chainName}

## Summary
This cross-chain proposal grants foundation roles to the Foundation multisig at ${foundationAddress} on ${chainName}.

## Actions
1. Grant GOVERNOR_ROLE in ProtocolAccessManager at ${protocolAccessManagerAddress}
2. Grant PROPOSER_ROLE in SummerTimelockController at ${timelockAddress}
3. Grant EXECUTOR_ROLE in SummerTimelockController at ${timelockAddress}
4. Grant CANCELLER_ROLE in SummerTimelockController at ${timelockAddress}
5. Grant DEFAULT_ADMIN_ROLE in SummerTimelockController at ${timelockAddress}
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 500000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(hubGovernorAddress)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: [
            {
              name: 'sendProposalToTargetChain',
              type: 'function',
              inputs: [
                { name: '_dstEid', type: 'uint32' },
                { name: '_dstTargets', type: 'address[]' },
                { name: '_dstValues', type: 'uint256[]' },
                { name: '_dstCalldatas', type: 'bytes[]' },
                { name: '_dstDescriptionHash', type: 'bytes32' },
                { name: '_options', type: 'bytes' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'sendProposalToTargetChain',
          args: [
            Number(currentChainEndpointId),
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

    // Get the effective target chains based on bummer config
    const effectiveTargetChains = useBummerConfig
      ? TARGET_CHAINS.filter((chain) => chain !== 'mainnet')
      : TARGET_CHAINS

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Multi-Chain Foundation Roles Setup`
    const description = `
# ${sipNumber}: Multi-Chain Foundation Roles Setup

## Summary
This proposal grants foundation roles to the Foundation multisig at ${foundationAddress} across all active chains in the Lazy Summer Protocol ecosystem.

## Motivation
The Foundation multisig requires specific roles to manage protocol governance and timelock operations:
- GOVERNOR_ROLE in ProtocolAccessManager for protocol-wide governance
- PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE, and DEFAULT_ADMIN_ROLE in SummerTimelockController for timelock management

## Target Address
Foundation Multisig: ${foundationAddress}

## Specifications

### Actions
1. On ${HUB_CHAIN_NAME}: 
   - Grant GOVERNOR_ROLE in ProtocolAccessManager
   - Grant PROPOSER_ROLE in SummerTimelockController
   - Grant EXECUTOR_ROLE in SummerTimelockController
   - Grant CANCELLER_ROLE in SummerTimelockController
   - Grant DEFAULT_ADMIN_ROLE in SummerTimelockController
${TARGET_CHAINS.filter(filterTargetChains)
  .map(
    (chain) => `2. Send cross-chain proposal to ${chain} to:
   - Grant GOVERNOR_ROLE in ProtocolAccessManager
   - Grant PROPOSER_ROLE in SummerTimelockController
   - Grant EXECUTOR_ROLE in SummerTimelockController
   - Grant CANCELLER_ROLE in SummerTimelockController
   - Grant DEFAULT_ADMIN_ROLE in SummerTimelockController`,
  )
  .join('\n')}

## Technical Details
- **GOVERNOR_ROLE**: Grants protocol-wide administrative privileges in the ProtocolAccessManager
- **PROPOSER_ROLE**: Allows proposing operations to the TimelockController
- **EXECUTOR_ROLE**: Allows executing operations in the TimelockController
- **CANCELLER_ROLE**: Allows cancelling operations in the TimelockController
- **DEFAULT_ADMIN_ROLE**: Grants admin privileges in the TimelockController, allowing role management
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Grant foundation roles on ${HUB_CHAIN_NAME} (5 actions)`,
      ...TARGET_CHAINS.filter(filterTargetChains).map(
        (chain) => `Send cross-chain proposal to ${chain} (5 actions)`,
      ),
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
      `${useBummerConfig ? 'test_foundation_roles' : 'foundation_roles'}_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow(`- Grant foundation roles on ${HUB_CHAIN_NAME} (5 actions)`))
    for (const chain of TARGET_CHAINS.filter(filterTargetChains)) {
      console.log(kleur.yellow(`- Send cross-chain proposal to ${chain} (5 actions)`))
    }

    // Use createGovernanceProposal directly to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions, // Add the cross-chain execution data
    )

    console.log(
      kleur.green('✅ Successfully created multi-chain Foundation roles governance proposal'),
    )
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
      ),
    )
  } catch (error) {
    console.error(kleur.red('Error creating multi-chain governance proposal:'), error)
    throw error
  }
}

// Execute the script
setupFoundationRoles().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { setupFoundationRoles }
