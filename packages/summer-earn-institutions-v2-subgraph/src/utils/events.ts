import { Address, ByteArray, Bytes, crypto, ethereum } from '@graphprotocol/graph-ts'

/**
 * @dev Decodes a bytes array into a tuple of values.
 * @param data The bytes array to decode.
 * @param signature The signature of the tuple to decode.
 * @returns A tuple of values.
 */
export function dataToTuple(data: Bytes, signature: String): ethereum.Tuple {
  return ethereum.decode(signature, data)!.toTuple()
}

let topic0: ByteArray
let _log: ethereum.Log
/**
 * @dev Retrieves an array of all logs matching a particular event name.
 * @param event The Ethereum event object to retrieve logs from.
 * @param eventName The name of the event to filter for.
 * @returns An array of Ethereum log objects that match the specified event name.
 */
export function getEventLogs(event: ethereum.Event, eventName: string): ethereum.Log[] {
  const receipt = event.receipt
  if (receipt == null) {
    return []
  }
  topic0 = getTopic0(eventName)

  return receipt.logs.filter((log) => {
    _log = log
    if (_log.topics.length == 0) {
      return false
    }
    return log.topics[0].equals(topic0)
  })
}

/**
 * @dev Retrieves the event signature hash for a given event name string.
 * @param eventSig The name of the event to retrieve the signature hash for.
 * @returns A byte array representing the keccak256 hash of the event signature.
 */
export function getTopic0(eventSig: string): ByteArray {
  const signature = ByteArray.fromUTF8(eventSig)

  return crypto.keccak256(signature)
}

/**
 * Decodes a bytes topic to an Ethereum address.
 * @param bytes The bytes topic to decode.
 * @returns The Ethereum address.
 * @throws An error if the bytes cannot be decoded to an address.
 * @dev use for non indexed topics only
 */
export function logTopicToAddress(bytes: Bytes): Address {
  const decoded = ethereum.decode('address', bytes)
  if (!decoded) {
    throw new Error('Cannot decode address')
  }

  return decoded.toAddress()
}
