// packages/deployment/scripts/governance/configure-layerzero-endpoint.ts

import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, encodeAbiParameters } from 'viem'
import { GovContracts } from '../../ignition/modules/gov'
import { getConfigByNetwork } from '../helpers/config-handler'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from '../helpers/tenderly-helpers'
import {
  createCrossChainLzConfigProposal,
  createLzConfigProposal,
} from './bridge-governance-helper'
import { LZ_ENDPOINT_ABI } from './lz-endpoint-abi'

/**
 * Configure LayerZero default settings for cross-chain communication
 */
async function configureLayerZeroEndpoint() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Configurations on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with configuration on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Configuration cancelled.'))
      return
    }
  }

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Load configuration based on the network
  const config = getConfigByNetwork(
    network,
    { common: false, gov: true, core: true },
    useBummerConfig,
  )

  // Get LayerZero configuration from loaded config
  const lzConfig = config.common.layerZero

  if (!lzConfig || !lzConfig.lzEndpoint) {
    console.log(kleur.red(`LayerZero configuration not found for network ${network}`))
    return
  }

  console.log(kleur.blue('LayerZero Endpoint:'), kleur.cyan(lzConfig.lzEndpoint))
  console.log(kleur.blue('Current Chain EID:'), kleur.cyan(lzConfig.eID))

  // Prompt for OApp selection
  const oAppOptions = [
    { title: 'SummerToken', value: 'summerToken' },
    { title: 'SummerGovernor', value: 'summerGovernor' },
  ]

  const { oAppChoice } = await prompts({
    type: 'select',
    name: 'oAppChoice',
    message: 'Select which OApp to configure:',
    choices: oAppOptions,
  })

  // Get OApp address from config
  const oAppAddress = config.deployedContracts.gov[oAppChoice as keyof GovContracts].address
  console.log(kleur.blue('Selected OApp:'), kleur.cyan(`${oAppChoice} at ${oAppAddress}`))

  // Prompt for target chain
  const targetChainChoices = [
    { title: 'Sonic', value: 'sonic' },
    { title: 'Base', value: 'base' },
    { title: 'Arbitrum', value: 'arbitrum' },
    { title: 'Mainnet', value: 'mainnet' },
  ]

  // Filter out current network from choices
  const availableTargetChains = targetChainChoices.filter((chain) => chain.value !== network)

  const { targetChain } = await prompts({
    type: 'select',
    name: 'targetChain',
    message: 'Select target chain to configure route to:',
    choices: availableTargetChains,
  })

  // Get target chain config to find EID
  const targetConfig = getConfigByNetwork(targetChain, { common: false }, useBummerConfig)
  const targetEid = parseInt(targetConfig.common.layerZero.eID)

  if (!targetEid) {
    console.log(kleur.red(`Target chain EID not found for ${targetChain}`))
    return
  }

  console.log(kleur.blue('Target Chain:'), kleur.cyan(targetChain))
  console.log(kleur.blue('Target Chain EID:'), kleur.cyan(targetEid.toString()))

  // Validate that we have DVNs in config
  if (!lzConfig.dvns || !lzConfig.dvns[targetChain as keyof typeof lzConfig.dvns]) {
    console.log(kleur.red(`Missing DVN configuration for route from ${network} to ${targetChain}`))
    console.log(
      kleur.yellow(
        `Please add dvns.${targetChain} with lzLabs and stargate addresses to the layerZero config for ${network}`,
      ),
    )
    return
  }

  // Get DVNs and executors from config
  const dvns = lzConfig.dvns[targetChain as keyof typeof lzConfig.dvns]

  // Ensure all required addresses are available
  if (!lzConfig.sendUln302 || !lzConfig.receiveUln302 || !dvns.lzLabs || !dvns.stargate) {
    console.log(kleur.red('Missing required contract addresses in config:'))
    if (!lzConfig.sendUln302) console.log(kleur.red('- sendUln302 missing'))
    if (!lzConfig.receiveUln302) console.log(kleur.red('- receiveUln302 missing'))
    if (!dvns.lzLabs) console.log(kleur.red('- dvns.lzLabs missing'))
    if (!dvns.stargate) console.log(kleur.red('- dvns.stargate missing'))
    return
  }

  const executors = {
    sendUln302: lzConfig.sendUln302,
    receiveUln302: lzConfig.receiveUln302,
  }

  // Versions (hardcoded as in the example)
  const sendVersion = 1n
  const receiveVersion = 1n

  // Set executor gas limit to 300K (in wei)
  const executorGasLimit = 300000n

  // ----------------- SEND CONFIG -----------------
  // Encode executor config correctly
  const executorConfig = {
    maxMessageSize: 10000, // Default max message size
    executorAddress: lzConfig.lzExecutor as Address, // Get executor address from config
  }

  // Encode ExecutorConfig
  const encodedExecutorConfig = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'maxMessageSize', type: 'uint32' },
          { name: 'executorAddress', type: 'address' },
        ],
      },
    ],
    [executorConfig],
  )

  // Encode ULN receive config for DVNs
  const dvnAddresses = [dvns.lzLabs as Address, dvns.stargate as Address].sort()

  const ulnConfig = {
    confirmations: 15n, // Keep as bigint - this is a uint64
    requiredDVNCount: 2, // Change to number
    optionalDVNCount: 0, // Change to number
    optionalDVNThreshold: 0, // Change to number
    requiredDVNs: dvnAddresses,
    optionalDVNs: [] as readonly Address[],
  }

  const encodedUlnConfig = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'confirmations', type: 'uint64' },
          { name: 'requiredDVNCount', type: 'uint8' },
          { name: 'optionalDVNCount', type: 'uint8' },
          { name: 'optionalDVNThreshold', type: 'uint8' },
          { name: 'requiredDVNs', type: 'address[]' },
          { name: 'optionalDVNs', type: 'address[]' },
        ],
      },
    ],
    [ulnConfig],
  )

  // Create send SetConfigParam array with both config types
  const sendConfigParams = [
    {
      eid: targetEid,
      configType: 1, // CONFIG_TYPE_EXECUTOR
      config: encodedExecutorConfig,
    },
    {
      eid: targetEid,
      configType: 2, // CONFIG_TYPE_ULN
      config: encodedUlnConfig,
    },
  ]

  // Create receive SetConfigParam array with only ULN config
  const receiveConfigParams = [
    {
      eid: targetEid,
      configType: 2, // CONFIG_TYPE_ULN
      config: encodedUlnConfig,
    },
  ]

  // Display configuration summary
  console.log(kleur.cyan().bold('\nConfiguration Summary:'))
  console.log(kleur.blue('- OApp:'), kleur.cyan(`${oAppChoice} (${oAppAddress})`))
  console.log(kleur.blue('- Target Chain:'), kleur.cyan(`${targetChain} (EID: ${targetEid})`))
  console.log(kleur.blue('- Send Library:'), kleur.cyan(executors.sendUln302))
  console.log(kleur.blue('- Receive Library:'), kleur.cyan(executors.receiveUln302))
  console.log(kleur.blue('- Send Version:'), kleur.cyan(sendVersion.toString()))
  console.log(kleur.blue('- Receive Version:'), kleur.cyan(receiveVersion.toString()))
  console.log(
    kleur.blue('- DVNs:'),
    kleur.cyan(`LZ Labs: ${dvns.lzLabs}, Stargate: ${dvns.stargate}`),
  )
  console.log(kleur.blue('- Executor Gas Limit:'), kleur.cyan(executorGasLimit.toString()))
  console.log(kleur.blue('- Send config: both executor and ULN configs'))
  console.log(kleur.blue('- Receive config: only ULN config'))

  // Get confirmation before proceeding
  const confirmation = await prompts({
    type: 'confirm',
    name: 'value',
    message: 'Proceed with this configuration?',
    initial: false,
  })

  if (!confirmation.value) {
    console.log(kleur.red('Operation cancelled'))
    return
  }

  try {
    console.log(kleur.green('Setting Send Library Configuration (both executor and ULN)...'))
    const [deployer] = await hre.viem.getWalletClients()
    console.log(kleur.blue('Using account:'), kleur.cyan(deployer.account.address))

    // Check if deployer is authorized (delegates)
    const publicClient = await hre.viem.getPublicClient()
    const delegate = await publicClient.readContract({
      address: lzConfig.lzEndpoint as Address,
      abi: LZ_ENDPOINT_ABI,
      functionName: 'delegates',
      args: [oAppAddress as Address],
    })

    console.log(kleur.blue('Delegate for OApp:'), kleur.cyan(delegate))

    if (delegate.toLowerCase() === deployer.account.address.toLowerCase()) {
      // Set send config with both config types
      const sendHash = await deployer.writeContract({
        address: lzConfig.lzEndpoint as Address,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [oAppAddress as Address, executors.sendUln302 as Address, sendConfigParams],
      })

      console.log(kleur.green(`Send library config transaction submitted: ${sendHash}`))

      // Wait for transaction receipt
      console.log(kleur.yellow('Waiting for send library config transaction confirmation...'))
      const sendReceipt = await publicClient.waitForTransactionReceipt({
        hash: sendHash,
      })

      console.log(
        kleur.green(
          `✅ Send library config transaction confirmed in block ${sendReceipt.blockNumber}`,
        ),
      )
      console.log(kleur.green(`✅ Gas used: ${sendReceipt.gasUsed}`))

      // Set receive config with only ULN config
      console.log(kleur.green('\nSetting Receive Library Configuration (only ULN config)...'))
      const receiveHash = await deployer.writeContract({
        address: lzConfig.lzEndpoint as Address,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [oAppAddress as Address, executors.receiveUln302 as Address, receiveConfigParams],
      })

      console.log(kleur.green(`Receive library config transaction submitted: ${receiveHash}`))

      // Wait for transaction receipt
      console.log(kleur.yellow('Waiting for receive library config transaction confirmation...'))
      const receiveReceipt = await publicClient.waitForTransactionReceipt({
        hash: receiveHash,
      })

      console.log(
        kleur.green(
          `✅ Receive library config transaction confirmed in block ${receiveReceipt.blockNumber}`,
        ),
      )
      console.log(kleur.green(`✅ Gas used: ${receiveReceipt.gasUsed}`))

      console.log(kleur.green('\n✅ LayerZero configuration complete!'))
    } else {
      console.log(kleur.yellow('Not authorized... generating governance proposal'))
      console.log(kleur.blue('Expected delegate:'), kleur.cyan(deployer.account.address))
      console.log(kleur.blue('Actual delegate:'), kleur.cyan(delegate))

      // Ask whether to create a standard or cross-chain governance proposal
      const { proposalType } = await prompts({
        type: 'select',
        name: 'proposalType',
        message: 'What type of governance proposal would you like to create?',
        choices: [
          { title: 'Standard Proposal (on current chain)', value: 'standard' },
          { title: 'Cross-chain Proposal (from hub chain)', value: 'crosschain' },
        ],
      })

      // Optional: Ask for a discourse URL to include with the proposal
      const { discourseURL } = await prompts({
        type: 'text',
        name: 'discourseURL',
        message: 'Enter a discourse URL for the proposal (optional):',
        initial: '',
      })

      // Create the appropriate type of proposal
      if (proposalType === 'standard') {
        await createLzConfigProposal(
          oAppAddress as Address,
          oAppChoice,
          lzConfig.lzEndpoint as Address,
          executors.sendUln302 as Address,
          executors.receiveUln302 as Address,
          sendConfigParams,
          receiveConfigParams,
          useBummerConfig,
          discourseURL,
        )
      } else {
        await createCrossChainLzConfigProposal(
          oAppAddress as Address,
          oAppChoice,
          lzConfig.lzEndpoint as Address,
          executors.sendUln302 as Address,
          executors.receiveUln302 as Address,
          sendConfigParams,
          receiveConfigParams,
          useBummerConfig,
          discourseURL,
        )
      }
    }
  } catch (error: any) {
    console.error(kleur.red('❌ Error setting LayerZero config:'))
    console.error(error instanceof Error ? error.message : String(error))
    if (error.cause) {
      console.error(kleur.red('Error cause:'), error.cause)
    }
  }
}

// Execute the script
if (require.main === module) {
  configureLayerZeroEndpoint().catch((error) => {
    console.error(kleur.red('Error during LayerZero endpoint configuration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
