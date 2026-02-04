import kleur from 'kleur'
import path from 'path'
import {
  Address,
  createPublicClient,
  encodeFunctionData,
  Hex,
  http,
  parseAbi,
  isAddress,
} from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigs } from '../helpers/chain-configs'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'
import { SupportedChain } from '../helpers/chain'

// ----------------------------------------------------------------------------
// CONFIGURATION
// ----------------------------------------------------------------------------

interface GuardianRequest {
  chain: SupportedChain
  address: Address // Guardian address to grant role to
  expiry?: number // Optional: Expiry timestamp in seconds (Unix timestamp)
  // If expiryDays is provided, it will be calculated from current time
  expiryDays?: number // Optional: Expiry in days from now (must be between 7 and 180)
}

// EDIT THIS ARRAY WITH YOUR GUARDIAN REQUESTS
const GUARDIAN_REQUESTS: GuardianRequest[] = [
  {
    chain: SupportedChain.mainnet,
    address: '0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4', // Replace with actual address
    expiryDays: 180, // 180 days from now
  },
  {
    chain: SupportedChain.base,
    address: '0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4', // Replace with actual address
    expiryDays: 180, // 180 days from now
  },
  {
    chain: SupportedChain.arbitrum,
    address: '0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4', // Replace with actual address
    expiryDays: 180, // 180 days from now
  },
  {
    chain: SupportedChain.sonic,
    address: '0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4', // Replace with actual address
    expiryDays: 180, // 180 days from now
  },
  // Example with explicit timestamp:
  // {
  //   chain: SupportedChain.sonic,
  //   address: '0x0000000000000000000000000000000000000000',
  //   expiry: Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60, // 90 days from now
  // },
  // Example without expiry (permanent guardian role):
  // {
  //   chain: SupportedChain.base,
  //   address: '0x0000000000000000000000000000000000000000',
  // },
]

// ----------------------------------------------------------------------------

const protocolAccessManagerAbi = parseAbi([
  'function grantGuardianRole(address account) external',
  'function setGuardianExpiration(address account, uint256 expiration) external',
  'function hasRole(bytes32 role, address account) external view returns (bool)',
  'function GUARDIAN_ROLE() external pure returns (bytes32)',
  'function guardianExpirations(address account) external view returns (uint256)',
])

// Constants from ProtocolAccessManager contract
const MIN_GUARDIAN_EXPIRY = 7n * 24n * 60n * 60n // 7 days in seconds
const MAX_GUARDIAN_EXPIRY = 180n * 24n * 60n * 60n // 180 days in seconds

async function main() {
  console.log(kleur.cyan().bold('=== Create Guardian Role Proposal ==='))

  if (GUARDIAN_REQUESTS.length === 0) {
    console.warn(
      kleur.yellow(
        'Warning: GUARDIAN_REQUESTS array is empty. Please edit the script to add guardian requests.',
      ),
    )
    return
  }

  const useBummerConfig = process.env.USE_BUMMER === 'true'
  console.log(kleur.yellow(`Using ${useBummerConfig ? 'bummer' : 'production'} configuration`))

  // Get all chain configs
  const chainConfigs = getChainConfigs(useBummerConfig)

  // Get hub chain configuration
  const hubConfig = chainConfigs[HUB_CHAIN_NAME]
  if (!hubConfig) {
    throw new Error(`Hub chain (${HUB_CHAIN_NAME}) not found in config`)
  }

  // Get proposer address
  const { walletClient } = createClients(hubConfig.chain, hubConfig.rpcUrl)
  const proposerAddress = walletClient.account.address

  console.log(kleur.blue(`Proposer address: ${proposerAddress}`))

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Lists to hold proposal data
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    const actionSummaries: string[] = []

    console.log(kleur.cyan('\nProcessing guardian requests...'))

    const currentTimestamp = BigInt(Math.floor(Date.now() / 1000))

    for (const req of GUARDIAN_REQUESTS) {
      const chainName = req.chain
      const chainConfig = chainConfigs[chainName]

      if (!chainConfig) {
        console.error(kleur.red(`Error: Chain '${chainName}' not found in configuration`))
        continue
      }

      // Validate address
      if (!isAddress(req.address)) {
        console.error(kleur.red(`Error: Invalid address '${req.address}' for chain '${chainName}'`))
        continue
      }

      // Get ProtocolAccessManager address
      const protocolAccessManagerAddress =
        (chainConfig.config.deployedContracts.govV2?.protocolAccessManager?.address as Address) ||
        (chainConfig.config.deployedContracts.gov?.protocolAccessManager?.address as Address)

      if (
        !protocolAccessManagerAddress ||
        protocolAccessManagerAddress === '0x0000000000000000000000000000000000000000'
      ) {
        console.error(
          kleur.red(`Error: ProtocolAccessManager address not found for chain '${chainName}'`),
        )
        continue
      }

      // Create public client for this chain
      const publicClient = createPublicClient({
        chain: chainConfig.chain,
        transport: http(chainConfig.rpcUrl),
      })

      // Check if address already has guardian role
      try {
        const GUARDIAN_ROLE = await publicClient.readContract({
          address: protocolAccessManagerAddress,
          abi: protocolAccessManagerAbi,
          functionName: 'GUARDIAN_ROLE',
        })

        const hasRole = await publicClient.readContract({
          address: protocolAccessManagerAddress,
          abi: protocolAccessManagerAbi,
          functionName: 'hasRole',
          args: [GUARDIAN_ROLE, req.address],
        })

        if (hasRole) {
          console.log(
            kleur.yellow(
              `Warning: Address ${req.address} already has GUARDIAN_ROLE on ${chainName}`,
            ),
          )
        }
      } catch (e) {
        console.warn(
          kleur.yellow(`Could not check existing role for ${req.address} on ${chainName}:`),
          e,
        )
      }

      // Calculate expiry timestamp
      let expiryTimestamp: bigint | undefined
      if (req.expiry !== undefined && req.expiryDays !== undefined) {
        console.error(
          kleur.red(
            `Error: Both 'expiry' and 'expiryDays' are provided for ${req.address} on ${chainName}. Please provide only one.`,
          ),
        )
        continue
      }

      if (req.expiry !== undefined) {
        expiryTimestamp = BigInt(req.expiry)
        // Validate that expiry is in the future
        if (expiryTimestamp <= currentTimestamp) {
          console.error(
            kleur.red(
              `Error: Expiry timestamp ${expiryTimestamp} is not in the future for ${req.address} on ${chainName}.`,
            ),
          )
          continue
        }
        // Validate expiry period is within bounds
        const expiryPeriod = expiryTimestamp - currentTimestamp
        if (expiryPeriod < MIN_GUARDIAN_EXPIRY || expiryPeriod > MAX_GUARDIAN_EXPIRY) {
          console.error(
            kleur.red(
              `Error: Expiry period for ${req.address} on ${chainName} is invalid. Must be between 7 and 180 days from now.`,
            ),
          )
          continue
        }
      } else if (req.expiryDays !== undefined) {
        // Validate expiryDays is a positive integer
        if (!Number.isInteger(req.expiryDays) || req.expiryDays <= 0) {
          console.error(
            kleur.red(
              `Error: expiryDays must be a positive integer for ${req.address} on ${chainName}.`,
            ),
          )
          continue
        }
        const expirySeconds = BigInt(req.expiryDays) * 24n * 60n * 60n
        expiryTimestamp = currentTimestamp + expirySeconds

        // Validate expiry period
        if (expirySeconds < MIN_GUARDIAN_EXPIRY || expirySeconds > MAX_GUARDIAN_EXPIRY) {
          console.error(
            kleur.red(
              `Error: Expiry period ${req.expiryDays} days is invalid. Must be between 7 and 180 days.`,
            ),
          )
          continue
        }
      }

      // Prepare calldatas
      const grantRoleCalldata = encodeFunctionData({
        abi: protocolAccessManagerAbi,
        functionName: 'grantGuardianRole',
        args: [req.address],
      })

      const actions: Array<{ target: Address; value: bigint; calldata: Hex }> = [
        {
          target: protocolAccessManagerAddress,
          value: 0n,
          calldata: grantRoleCalldata,
        },
      ]

      // Add expiry action if provided
      if (expiryTimestamp !== undefined) {
        const setExpiryCalldata = encodeFunctionData({
          abi: protocolAccessManagerAbi,
          functionName: 'setGuardianExpiration',
          args: [req.address, expiryTimestamp],
        })

        actions.push({
          target: protocolAccessManagerAddress,
          value: 0n,
          calldata: setExpiryCalldata,
        })
      }

      // Build summary
      const expiryText = expiryTimestamp
        ? ` (expires: ${new Date(Number(expiryTimestamp) * 1000).toISOString()})`
        : ' (no expiry)'
      const summary = `Grant guardian role to ${req.address} on ${chainName}${expiryText}`
      actionSummaries.push(summary)
      console.log(kleur.blue(`Adding action: ${summary}`))

      if (chainName === HUB_CHAIN_NAME) {
        // Direct execution on Hub chain
        for (const action of actions) {
          srcTargets.push(action.target)
          srcValues.push(action.value)
          srcCalldatas.push(action.calldata)
        }
      } else {
        // Cross-chain execution
        const dstTargets: Address[] = actions.map((a) => a.target)
        const dstValues: bigint[] = actions.map((a) => a.value)
        const dstCalldatas: Hex[] = actions.map((a) => a.calldata)

        const chainId = chainConfig.chain.id

        crossChainExecutions.push({
          name: chainName,
          chainId: Number(chainId),
          targets: dstTargets.map((t) => t as string),
          values: dstValues.map((v) => v.toString()),
          datas: dstCalldatas.map((c) => c as string),
        })

        // Add Cross-Chain Proposal Action to Hub
        const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
          .address as Address
        const currentChainEndpointId = chainConfig.config.common.layerZero.eID

        const dstDescription = `
# Grant Guardian Role on ${chainName}

## Summary
Grant guardian role to ${req.address}${expiryText}.
`.trim()

        const ESTIMATED_GAS = 400000n // Standard estimate
        const lzOptions = constructLzOptions(ESTIMATED_GAS)

        srcTargets.push(hubGovernorAddress)
        srcValues.push(0n)
        srcCalldatas.push(
          encodeFunctionData({
            abi: parseAbi([
              'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
            ]),
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
      }
    }

    if (srcTargets.length === 0) {
      console.log(kleur.yellow('No actions to create.'))
      return
    }

    // Step 3: Create Proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Grant Guardian Roles`
    const description = `
# ${sipNumber}: Grant Guardian Roles

## Summary
This proposal grants guardian roles to specified addresses across multiple chains.

## Actions
${actionSummaries.map((s) => `- ${s}`).join('\n')}
`.trim()

    // Generate a save path
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const savePath = path.join(process.cwd(), '/proposals', `guardian_role_${timestamp}.json`)

    console.log(kleur.cyan('\nCreating governance proposal...'))

    // Create Action Objects
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
      .address as Address

    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '',
      actionSummaries,
      savePath,
      crossChainExecutions.length > 0 ? crossChainExecutions : undefined,
    )

    console.log(kleur.green('✅ Successfully created proposal'))
    console.log(kleur.yellow(`Saved to: ${savePath}`))
  } catch (error) {
    console.error(kleur.red('Error creating proposal:'), error)
    throw error
  }
}

main().catch(console.error)
