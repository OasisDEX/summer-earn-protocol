export const fleetCommanderAbi = [
  {
    type: 'function',
    name: 'getActiveArks',
    inputs: [],
    outputs: [{ type: 'address[]', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'bufferArk',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'totalAssets',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'withdrawableTotalAssets',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'asset',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'name',
    inputs: [],
    outputs: [{ type: 'string', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'symbol',
    inputs: [],
    outputs: [{ type: 'string', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ type: 'uint8', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'maxDeposit',
    inputs: [{ type: 'address', name: 'owner' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'maxWithdraw',
    inputs: [{ type: 'address', name: 'owner' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'deposit',
    inputs: [
      { type: 'uint256', name: 'assets' },
      { type: 'address', name: 'receiver' }
    ],
    outputs: [{ type: 'uint256', name: 'shares' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'withdraw',
    inputs: [
      { type: 'uint256', name: 'assets' },
      { type: 'address', name: 'receiver' },
      { type: 'address', name: 'owner' }
    ],
    outputs: [{ type: 'uint256', name: 'shares' }],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'rebalance',
    inputs: [
      {
        type: 'tuple[]',
        name: 'rebalanceData',
        components: [
          { type: 'address', name: 'fromArk' },
          { type: 'address', name: 'toArk' },
          { type: 'uint256', name: 'amount' },
          { type: 'bytes', name: 'boardData' },
          { type: 'bytes', name: 'disembarkData' }
        ]
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  // Ark Management Methods
  {
    type: 'function',
    name: 'setArkDepositCap',
    inputs: [
      { type: 'address', name: 'ark' },
      { type: 'uint256', name: 'newDepositCap' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setArkMaxDepositPercentageOfTVL',
    inputs: [
      { type: 'address', name: 'ark' },
      { type: 'uint256', name: 'newMaxDepositPercentageOfTVL' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setArkMaxRebalanceOutflow',
    inputs: [
      { type: 'address', name: 'ark' },
      { type: 'uint256', name: 'newMaxRebalanceOutflow' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setArkMaxRebalanceInflow',
    inputs: [
      { type: 'address', name: 'ark' },
      { type: 'uint256', name: 'newMaxRebalanceInflow' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  // Fleet-level Management Methods
  {
    type: 'function',
    name: 'setMinimumBufferBalance',
    inputs: [
      { type: 'uint256', name: 'newMinimumBalance' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setFleetDepositCap',
    inputs: [
      { type: 'uint256', name: 'newCap' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setMaxRebalanceOperations',
    inputs: [
      { type: 'uint256', name: 'newMaxRebalanceOperations' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'setFleetTokenTransferability',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  // Add/Remove Arks
  {
    type: 'function',
    name: 'addArk',
    inputs: [
      { type: 'address', name: 'ark' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'removeArk',
    inputs: [
      { type: 'address', name: 'ark' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  // View methods for current values
  {
    type: 'function',
    name: 'getConfig',
    inputs: [],
    outputs: [
      {
        type: 'tuple',
        name: '',
        components: [
          { type: 'address', name: 'bufferArk' },
          { type: 'uint256', name: 'minimumBufferBalance' },
          { type: 'uint256', name: 'depositCap' },
          { type: 'uint256', name: 'maxRebalanceOperations' },
          { type: 'address', name: 'stakingRewardsManager' }
        ]
      }
    ],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'transfersEnabled',
    inputs: [],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  }
] as const; 