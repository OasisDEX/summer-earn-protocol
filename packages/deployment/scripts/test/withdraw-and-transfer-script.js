// Using an IIFE to avoid leaking globals across sibling scripts
;(function () {
  // Using viem to encode FleetProxy.withdrawAndTransfer BridgeOptions and calldata
  const { encodeFunctionData, parseAbi, encodeAbiParameters } = require('viem')

  // Amount to withdraw and bridge (example: 1 USDC with 6 decimals)
  // Customize this for your scenario/decimals
  const amount = 900000n

  // BridgeOptions with adapter settings
  // Customize these for your deployment/adapters/fees
  const bridgeOptions = {
    specifiedAdapter: '0x22CFc995087F8FcdE8889C1C3c7c35E63403a239', // Example: Stargate adapter
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

  // Encode withdrawAndTransfer function call for FleetProxy
  const fleetProxyAbi = parseAbi([
    'function withdrawAndTransfer(uint256 amount, (address specifiedAdapter, uint64 gasLimit, uint32 calldataSize, uint128 msgValue, bytes options) options) payable',
  ])

  const data = encodeFunctionData({
    abi: fleetProxyAbi,
    functionName: 'withdrawAndTransfer',
    args: [amount, bridgeOptions],
  })

  // Output helpers for Etherscan/manual invocation
  const etherscanBridgeOptionsTuple = [
    bridgeOptions.specifiedAdapter,
    bridgeOptions.gasLimit,
    bridgeOptions.calldataSize,
    bridgeOptions.msgValue,
    bridgeOptions.options,
  ]

  console.log('Amount (uint256):')
  console.log(amount.toString())
  console.log('\nBridgeOptions encoded:')
  console.log(encodedBridgeOptions)
  console.log('\nCalldata for withdrawAndTransfer:')
  console.log(data)
  console.log('\nEtherscan BridgeOptions tuple:')
  console.log(JSON.stringify(etherscanBridgeOptionsTuple, null, 2))
})()
