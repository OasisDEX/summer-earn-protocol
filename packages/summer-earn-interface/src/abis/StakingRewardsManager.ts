export const stakingRewardsManagerAbi = [
  // View functions
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'totalSupply',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'stakingToken',
    inputs: [],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'earned',
    inputs: [
      { type: 'address', name: 'account' },
      { type: 'address', name: 'rewardToken' }
    ],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'rewardTokens',
    inputs: [{ type: 'uint256', name: 'index' }],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'rewardTokensLength',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'rewardPerToken',
    inputs: [{ type: 'address', name: 'rewardToken' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'lastTimeRewardApplicable',
    inputs: [{ type: 'address', name: 'rewardToken' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getRewardForDuration',
    inputs: [{ type: 'address', name: 'rewardToken' }],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'isRewardToken',
    inputs: [{ type: 'address', name: 'rewardToken' }],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  },
  
  // Mutative functions
  {
    type: 'function',
    name: 'stake',
    inputs: [{ type: 'uint256', name: 'amount' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'unstake',
    inputs: [{ type: 'uint256', name: 'amount' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'getReward',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'getReward',
    inputs: [{ type: 'address', name: 'rewardToken' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'exit',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  
  // Events
  {
    type: 'event',
    name: 'Staked',
    inputs: [
      { type: 'address', name: 'staker', indexed: true },
      { type: 'address', name: 'receiver', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'Unstaked',
    inputs: [
      { type: 'address', name: 'staker', indexed: true },
      { type: 'address', name: 'receiver', indexed: true },
      { type: 'uint256', name: 'amount', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'RewardPaid',
    inputs: [
      { type: 'address', name: 'user', indexed: true },
      { type: 'address', name: 'rewardToken', indexed: true },
      { type: 'uint256', name: 'reward', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'RewardAdded',
    inputs: [
      { type: 'address', name: 'rewardToken', indexed: true },
      { type: 'uint256', name: 'reward', indexed: false }
    ]
  }
] as const