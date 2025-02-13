import { Address, Hex, encodeFunctionData, parseAbi } from 'viem'
import { ChainSetup } from './chain-prompt'
import { hashDescription } from './hash-description'
import { constructLzOptions } from './layerzero-options'

export interface CrossChainAction {
  target: Address
  value: bigint
  calldata: Hex
}

/**
 * Builds a cross-chain proposal action that can be executed on the source chain
 * to create a proposal on a target chain.
 *
 * @param params Configuration parameters for the cross-chain proposal
 * @returns A proposal action that can be included in a source chain proposal
 */
export async function buildCrossChainProposalAction(params: {
  targetChain: ChainSetup
  targets: Address[]
  values: bigint[]
  calldatas: Hex[]
  description: string
  governorAddress: Address
  gasLimit?: bigint
}): Promise<CrossChainAction> {
  const {
    targetChain,
    targets,
    values,
    calldatas,
    description,
    governorAddress,
    gasLimit = 350000n,
  } = params

  const targetEndpointId = targetChain.config.common.layerZero.eID
  const lzOptions = constructLzOptions(gasLimit)

  const crossChainCalldata = encodeFunctionData({
    abi: parseAbi([
      'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
    ]),
    args: [
      Number(targetEndpointId),
      targets,
      values,
      calldatas,
      hashDescription(description),
      lzOptions,
    ],
  }) as Hex

  console.log(`Prepared cross-chain proposal action for chain ${targetChain.name}`)

  return {
    target: governorAddress,
    value: 0n,
    calldata: crossChainCalldata,
  }
}
