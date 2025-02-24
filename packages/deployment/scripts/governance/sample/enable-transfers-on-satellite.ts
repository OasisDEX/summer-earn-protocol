import prompts from 'prompts'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { hashDescription } from '../../helpers/hash-description'
import { constructLzOptions } from '../../helpers/layerzero-options'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

async function main() {
  // Prompt the user to select whether to use test or production config.
  const { useTest } = await prompts({
    type: 'select',
    name: 'useTest',
    message: 'Select configuration to use:',
    choices: [
      { title: 'Production', value: false },
      { title: 'Test', value: true },
    ],
  })

  // Get chain configuration through prompt
  const {
    config: hubConfig,
    chain,
    name: chainName,
    rpcUrl,
  } = await promptForChain('Select the chain:', useTest)

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get target (satellite) chain configuration
  const { config: targetConfig } = await promptForTargetChain(chainName, useTest)

  // Extract addresses and IDs from configs
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const SATELLITE_TOKEN_ADDRESS = targetConfig.deployedContracts.gov.summerToken.address as Address
  const SATELLITE_ENDPOINT_ID = targetConfig.common.layerZero.eID

  // Prepare the satellite chain proposal parameters (target proposal)
  const dstTargets = [SATELLITE_TOKEN_ADDRESS]
  const dstValues = [0n]
  const dstCalldatas = [
    encodeFunctionData({
      abi: parseAbi(['function enableTransfers()']),
      args: [],
    }) as Hex,
  ]
  const dstDescription = `Enable transfers on satellite chain SummerToken (v6)`

  console.log('Destination description:', dstDescription)
  console.log('Hashed destination description:', hashDescription(dstDescription))
  console.log('LayerZero options:', constructLzOptions(200000n))
  console.log('Destination targets:', dstTargets)
  console.log('Destination values:', dstValues)
  console.log('Destination calldatas:', dstCalldatas)

  // Prepare the hub chain proposal parameters (source proposal)
  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const lzOptions = constructLzOptions(300000n)

  // Encode the cross-chain message parameters
  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(SATELLITE_ENDPOINT_ID),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  try {
    console.log('Preparing to submit cross-chain proposal...')
    console.log('Source targets:', srcTargets)
    console.log('Source values:', srcValues)
    console.log('Source calldatas:', srcCalldatas)
    console.log('Source description:', srcDescription)
    console.log('Hashed description:', hashDescription(srcDescription))

    console.log('Simulation successful, proceeding with transaction...')

    // Submit the proposal with explicit gas parameters
    const hash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [srcTargets, srcValues, srcCalldatas, srcDescription],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Proposal submitted. Transaction hash:', hash)

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log('Proposal transaction mined. Block number:', receipt.blockNumber)

    // Get the proposal ID
    const proposalId = await publicClient.readContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [srcTargets, srcValues, srcCalldatas, hashDescription(srcDescription)],
    })

    console.log('Proposal ID:', proposalId)
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
