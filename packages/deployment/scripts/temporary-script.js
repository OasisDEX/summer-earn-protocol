// Using viem to encode the rebalance function call and CrossChainArk board data
const { encodeFunctionData, parseAbi, encodeAbiParameters } = require('viem')

// Rebalance data for moving 1 USDC from BufferArk to the CrossChainArk
const rebalanceData = [
  {
    fromArk: '0x37a0CED093Be494e09CD5867aC5F32741E6a6392', // BufferArk
    toArk: '0xA69e129038cCb75BCA01874a2281CfcAa49D7E81', // CrossChainArk
    amount: 1000000n, // 1 USDC (6 decimals)
    boardData: '0x', // Will be populated below
    disembarkData: '0x',
  },
]

// CrossChainArk board data structure
// This needs to be customized for your specific deployment
const crossChainArkBoardData = {
  // ExecuteTransferParams
  executeTransferParams: {
    originator: '0xA69e129038cCb75BCA01874a2281CfcAa49D7E81', // CrossChainArk address
    destinationChainId: 8453, // Base chain ID
    target: '0x113E5a468b2DdF550FD714ef6f6FF8DC96B480F7', // FleetProxy address (set to 0x0 if not deployed yet)
    asset: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85', // USDC on Unichain
    amount: 1000000n, // 1 USDC
    message: '0x', // Empty message for transfer
    refundAddress: '0xb0f758323D3798a6A567C1601d84f30d1BCAAA0b', // Set to appropriate refund address
  },
  // BridgeOptions with Stargate adapter
  bridgeOptions: {
    specifiedAdapter: '0x1b4b8c790A36F2e37bCd59db73320D6Fd897DB9A', // Stargate adapter
    gasLimit: 1500000, // Gas limit for execution on destination
    msgValue: 0, // Native value to forward
    calldataSize: 0, // Size of expected return calldata
    options: '0x', // Additional adapter-specific parameters
  },
}

// Encode the board data for CrossChainArk
const boardDataEncoded = encodeAbiParameters(
  [
    // ExecuteTransferParams struct
    {
      type: 'tuple',
      components: [
        { name: 'originator', type: 'address' },
        { name: 'destinationChainId', type: 'uint16' },
        { name: 'target', type: 'address' },
        { name: 'asset', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'message', type: 'bytes' },
        { name: 'refundAddress', type: 'address' },
      ],
    },
    // BridgeOptions struct
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
  [crossChainArkBoardData.executeTransferParams, crossChainArkBoardData.bridgeOptions],
)

// Update the rebalance data with the encoded board data
rebalanceData[0].boardData = boardDataEncoded

// Encode the rebalance function call
const rebalanceAbi = parseAbi([
  'function rebalance((address fromArk, address toArk, uint256 amount, bytes boardData, bytes disembarkData)[] data) external',
])

const calldata = encodeFunctionData({
  abi: rebalanceAbi,
  functionName: 'rebalance',
  args: [rebalanceData],
})

// Output tuple[] JSON for Etherscan input box
const etherscanTupleArray = rebalanceData.map((item) => [
  item.fromArk,
  item.toArk,
  item.amount.toString(),
  item.boardData,
  item.disembarkData,
])

console.log('Board data encoded for CrossChainArk:')
console.log(boardDataEncoded)
console.log('\nEtherscan tuple array:')
console.log(JSON.stringify(etherscanTupleArray, null, 2))
