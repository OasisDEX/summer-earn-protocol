import { Address, BigInt, ByteArray, Bytes, crypto, ethereum, log } from '@graphprotocol/graph-ts'
import {
  Multicall,
  Multicall__aggregateInputCallsStruct,
  Multicall__aggregateResult,
} from '../../generated/HarborCommand/Multicall'

const MULTICALL_ADDRESS = Address.fromString('0xcA11bde05977b3631167028862bE2a173976CA11')

/**
 * Prepares a multicall call with the given target address and calldata.
 * @param target The target address to call.
 * @param calldata The calldata to include in the call.
 * @returns A tuple containing the target address and calldata.
 * @dev solidity struct of the `Call` type:
 *     struct Call {
 *       address target;
 *       bytes callData;
 *   }
 */
export function prepareMulicallCall(target: Address, calldata: Bytes): ethereum.Tuple {
  const call = new ethereum.Tuple()
  call[0] = ethereum.Value.fromAddress(target)
  call[1] = ethereum.Value.fromBytes(calldata)
  return call
}

/**
 * Encodes values for a given function signature and its corresponding types.
 *
 * @param signature - The function signature.
 * @param types - The types of the function arguments.
 * @param values - The values of the function arguments.
 * @returns The encoded values as a Bytes object.
 * @throws An error if the types and values arrays have different lengths or if the arrays have more than 10 elements.
 */
export function encodeFunctionCalldata(
  signature: string,
  types: string[],
  values: string[],
): Bytes {
  if (types.length !== values.length) {
    throw new Error('Types and values arrays must have the same length')
  }
  if (types.length > 10) {
    throw new Error('Arrays with more than 10 elements are not supported')
  }
  let final = getSelector(signature)
  for (let i = 0; i < types.length; i++) {
    const encodedValue = encodeValue(values[i], types[i])
    if (!encodedValue) {
      throw new Error('Could not encode value')
    }
    final = final.concat(encodedValue)
  }
  return final
}

/**
 * Returns the selector for a given function signature.
 * @param functionSignature - The function signature to get the selector for.
 * @returns The selector for the given function signature.
 */
export function getSelector(functionSignature: string): Bytes {
  const signatureBytes = ByteArray.fromUTF8(functionSignature)
  const selectorUint8Array = crypto.keccak256(signatureBytes).subarray(0, 4)
  const selector = Bytes.fromUint8Array(selectorUint8Array)
  return selector
}

export function makeMulticall(
  calls: ethereum.Tuple[],
): ethereum.CallResult<Multicall__aggregateResult> {
  const multicall = Multicall.bind(MULTICALL_ADDRESS)
  const multicallResponse = try_aggregate(calls, multicall)

  return multicallResponse
}

export function radToUnit(value: ethereum.Tuple[]): Multicall__aggregateInputCallsStruct[] {
  return changetype<Multicall__aggregateInputCallsStruct[]>(value)
}

/**
 * Decodes the given data using the provided types and returns an array of decoded values as strings.
 * @param types - The types of the data to decode.
 * @param data - The data to decode.
 * @returns An array of decoded values as strings.
 */
export function decodeValues(types: string, data: Bytes): string[] {
  const result = ethereum.decode(types, data)
  if (result) {
    if (result.kind == ethereum.ValueKind.TUPLE) {
      return convertDecodedDataToStringArray(result)
    } else {
      return [convertDecodedDataToString(result)]
    }
  } else {
    return ['']
  }
}

/**
 * Converts decoded ethereum data tuple to a string array.
 * @param data The decoded ethereum data tuple to convert.
 * @returns An array of strings representing the decoded data.
 */
export function convertDecodedDataToStringArray(data: ethereum.Value): string[] {
  if (data.kind == ethereum.ValueKind.TUPLE) {
    const t = data.toTuple()
    const decodedArray = new Array<string>(t.length)
    for (let i = 0; i < t.length; i++) {
      decodedArray[i] = convertDecodedDataToString(t[i])
    }
    return decodedArray
  } else {
    log.warning('Decoded data is not a tuple', [])
    return ['']
  }
}

/**
 * Converts decoded data to a string representation.
 *
 * @param decoded - The decoded data to convert.
 * @returns The string representation of the decoded data.
 */
export function convertDecodedDataToString(data: ethereum.Value): string {
  if (data.kind == ethereum.ValueKind.ADDRESS) {
    return data.toAddress().toHexString()
  } else if (data.kind == ethereum.ValueKind.INT || data.kind == ethereum.ValueKind.UINT) {
    return data.toBigInt().toString()
  } else if (data.kind == ethereum.ValueKind.BOOL) {
    return data.toBoolean().toString()
  } else if (data.kind == ethereum.ValueKind.BYTES) {
    return data.toBytes().toHexString()
  } else if (data.kind == ethereum.ValueKind.STRING) {
    return data.toString()
  } else {
    log.warning('Decoded data not suported. Kind: {}', [data.kind.toString()])
    return ''
  }
}

/**
 * Prepares a multicall call with the given target address and function signature.
 * @param target The target address to call.
 * @param functionSignature The function signature to include in the call.
 * @returns A tuple containing the target address and calldata.
 */
function try_aggregate(
  calls: Array<ethereum.Tuple>,
  multicall: Multicall = Multicall.bind(MULTICALL_ADDRESS),
): ethereum.CallResult<Multicall__aggregateResult> {
  let result = multicall.tryCall('aggregate', 'aggregate((address,bytes)[]):(uint256,bytes[])', [
    ethereum.Value.fromTupleArray(calls),
  ])
  if (result.reverted) {
    return new ethereum.CallResult()
  }
  let value = result.value
  return ethereum.CallResult.fromValue(
    new Multicall__aggregateResult(value[0].toBigInt(), value[1].toBytesArray()),
  )
}

/**
 * Encodes a value of a given type for use in Ethereum smart contracts.
 * @param value The value to encode.
 * @param type The type of the value to encode.
 * @returns The encoded value as a Bytes object, or null if the type is not supported.
 * @throws An error if the type is not supported.
 */
function encodeValue(value: string, type: string): Bytes | null {
  if (type == 'address') {
    return ethereum.encode(ethereum.Value.fromAddress(Address.fromString(value)))
  } else if (type == 'bool') {
    let boolValue = value == 'true' ? true : false
    return ethereum.encode(ethereum.Value.fromBoolean(boolValue))
  } else if (type == 'uint256' || type == 'uint16' || type == 'uint32') {
    return ethereum.encode(ethereum.Value.fromUnsignedBigInt(BigInt.fromString(value)))
  } else if (type == 'bytes32') {
    const temp = ethereum
      .encode(ethereum.Value.fromBytes(Bytes.fromHexString(value)))!
      .subarray(-32)
    const tempRes = Bytes.fromUint8Array(temp)
    return tempRes
  } else {
    throw new Error(`Unsupported type: ${type}`)
  }
}
