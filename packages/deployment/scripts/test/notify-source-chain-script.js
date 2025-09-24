// Using an IIFE to avoid leaking globals across sibling scripts
;(function () {
  // Using viem to encode FleetProxy.notifySourceChain BridgeOptions and calldata
  const { encodeFunctionData, parseAbi, encodeAbiParameters } = require('viem')

  // BridgeOptions with adapter settings
  // Customize these for your deployment/adapters/fees
  const bridgeOptions = {
    specifiedAdapter: '0x6C79DEAD6399fD1E757cC14876bb3602727a304f', // Example: Stargate adapter
    gasLimit: 3000000, // Gas limit for destination execution
    calldataSize: 0, // Expected return calldata size
    msgValue: 0, // Native value forwarded to adapter (not the tx value)
    options: '0x', // Adapter-specific options blob
  }

  // Encode BridgeOptions tuple (useful for verification/debug)
  const encodedBridgeOptions = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'specifiedAdapter', type: 'address' },
          { name: 'gasLimit', type: 'uint64' },
          { name: 'calldataSize', type: 'uint32' },
          { name: 'msgValue', type: 'uint128' },
          { name: 'options', type: 'bytes' },
        ],
      },
    ],
    [bridgeOptions],
  )

  // Encode notifySourceChain function call for FleetProxy
  const fleetProxyAbi = parseAbi([
    'function notifySourceChain((address specifiedAdapter, uint64 gasLimit, uint32 calldataSize, uint128 msgValue, bytes options) options) payable',
  ])

  const data = encodeFunctionData({
    abi: fleetProxyAbi,
    functionName: 'notifySourceChain',
    args: [bridgeOptions],
  })

  // Output helpers for Etherscan/manual invocation
  const etherscanTuple = [
    bridgeOptions.specifiedAdapter,
    bridgeOptions.gasLimit,
    bridgeOptions.calldataSize,
    bridgeOptions.msgValue,
    bridgeOptions.options,
  ]

  console.log('BridgeOptions encoded:')
  console.log(encodedBridgeOptions)
  console.log('\nCalldata for notifySourceChain:')
  console.log(data)
  console.log('\nEtherscan tuple:')
  console.log(JSON.stringify(etherscanTuple, null, 2))
})()
