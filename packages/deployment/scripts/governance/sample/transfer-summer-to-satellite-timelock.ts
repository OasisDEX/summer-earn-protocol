import { addressToBytes32 } from '@layerzerolabs/lz-v2-utilities'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { promptForChain, promptForTargetChain } from '../../helpers/chain-prompt'
import { constructLzOptions } from '../../helpers/layerzero-options'
import { createClients } from '../../helpers/wallet-helper'

const governorAbi = parseAbi([
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
  'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
])

const oftAbi = [
  {
    name: 'quoteSend',
    inputs: [
      {
        name: 'sendParam',
        type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
      },
      { name: 'payInLzToken', type: 'bool' },
    ],
    outputs: [
      { name: 'nativeFee', type: 'uint256' },
      { name: 'lzTokenFee', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    name: 'send',
    inputs: [
      {
        name: 'sendParam',
        type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
      },
      {
        name: 'fee',
        type: 'tuple',
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ],
      },
      { name: 'refundAddress', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    type: 'error',
    name: 'InsufficientBalance',
    inputs: [
      { name: 'required', type: 'uint256' },
      { name: 'balance', type: 'uint256' },
    ],
  },
  {
    type: 'error',
    name: 'InvalidAmount',
    inputs: [],
  },
  {
    type: 'error',
    name: 'NoPeer',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ERC20InsufficientAllowance',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'allowance', type: 'uint256' },
      { name: 'needed', type: 'uint256' },
    ],
  },
  {
    type: 'error',
    name: 'ERC20InvalidSender',
    inputs: [{ name: 'sender', type: 'address' }],
  },
  {
    type: 'error',
    name: 'LZ_ULN_UnsupportedOptionType',
    inputs: [{ name: 'optionType', type: 'uint16' }],
  },
] as const

async function promptForAmount(): Promise<{ amount: bigint; amountWei: bigint }> {
  const response = await prompts({
    type: 'number',
    name: 'amount',
    message: 'Enter the amount of SUMMER tokens to transfer (in whole tokens):',
    validate: (value) => value > 0 || 'Amount must be greater than 0',
  })

  // Convert to wei (18 decimals)
  const amount = BigInt(response.amount)
  return { amount, amountWei: amount * 10n ** 18n }
}

async function main() {
  // Get hub (source) chain configuration
  const {
    config: hubConfig,
    chain,
    rpcUrl,
    name: hubChainName,
  } = await promptForChain('Select hub chain:')

  const { publicClient, walletClient } = createClients(chain, rpcUrl)

  // Get satellite (target) chain configuration
  const { config: satelliteConfig } = await promptForTargetChain(hubChainName)

  // Get transfer amount from user
  const { amount: HUMAN_READABLE_AMOUNT, amountWei: TRANSFER_AMOUNT } = await promptForAmount()

  // Extract addresses and IDs
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const HUB_TOKEN_ADDRESS = hubConfig.deployedContracts.gov.summerToken.address as Address
  const HUB_TIMELOCK_ADDRESS = hubConfig.deployedContracts.gov.timelock.address as Address
  const SATELLITE_TIMELOCK_ADDRESS = satelliteConfig.deployedContracts.gov.timelock
    .address as Address
  const SATELLITE_ENDPOINT_ID = satelliteConfig.common.layerZero.eID

  // Create send parameters with options
  const options = constructLzOptions(300000n)
  console.log('Generated options:', options)

  const recipientHex = `0x${Buffer.from(addressToBytes32(SATELLITE_TIMELOCK_ADDRESS)).toString(
    'hex',
  )}` as `0x${string}`
  console.log('Recipient hex:', recipientHex)

  const sendParam = {
    dstEid: Number(SATELLITE_ENDPOINT_ID),
    to: recipientHex,
    amountLD: TRANSFER_AMOUNT,
    minAmountLD: TRANSFER_AMOUNT,
    extraOptions: options,
    composeMsg: '0x' as `0x${string}`,
    oftCmd: '0x' as `0x${string}`,
  }

  // Quote the fees before creating the proposal
  console.log('Quoting cross-chain fees...')
  const [nativeFee, lzTokenFee] = await publicClient.readContract({
    address: HUB_TOKEN_ADDRESS,
    abi: oftAbi,
    functionName: 'quoteSend',
    args: [sendParam, false] as const,
  })

  console.log(`Native fee: ${nativeFee} wei`)
  console.log(`LZ token fee: ${lzTokenFee} wei`)

  // Transfer proposal
  const transferTargets = [HUB_TOKEN_ADDRESS]
  const transferValues = [nativeFee]
  const transferCalldatas = [
    encodeFunctionData({
      abi: oftAbi,
      functionName: 'send',
      args: [
        sendParam,
        { nativeFee, lzTokenFee },
        HUB_TIMELOCK_ADDRESS, // Refund address
      ],
    }) as Hex,
  ]

  const transferDescription = `Transfer ${HUMAN_READABLE_AMOUNT} SUMMER tokens from hub timelock to satellite timelock`

  try {
    console.log('Submitting transfer proposal...')
    const transferHash = await walletClient.writeContract({
      address: HUB_GOVERNOR_ADDRESS,
      abi: governorAbi,
      functionName: 'propose',
      args: [transferTargets, transferValues, transferCalldatas, transferDescription],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log('Transfer proposal submitted. Transaction hash:', transferHash)
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
