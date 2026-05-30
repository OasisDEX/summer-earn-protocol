// ABI for the TipJar contract (core-contracts/src/contracts/TipJar.sol).
// `allocation` is a `Percentage` (uint256, 18 decimals: 1% = 1e18, 100% = 100e18).
export const tipJarAbi = [
  {
    type: 'function',
    name: 'getAllTipStreams',
    inputs: [],
    outputs: [
      {
        type: 'tuple[]',
        name: 'allStreams',
        components: [
          { type: 'address', name: 'recipient' },
          { type: 'uint256', name: 'allocation' },
          { type: 'uint256', name: 'lockedUntilEpoch' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTipStream',
    inputs: [{ type: 'address', name: 'recipient' }],
    outputs: [
      {
        type: 'tuple',
        name: '',
        components: [
          { type: 'address', name: 'recipient' },
          { type: 'uint256', name: 'allocation' },
          { type: 'uint256', name: 'lockedUntilEpoch' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTotalAllocation',
    inputs: [],
    outputs: [{ type: 'uint256', name: 'total' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'paused',
    inputs: [],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'shake',
    inputs: [{ type: 'address', name: 'fleetCommander_' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'shakeMultiple',
    inputs: [{ type: 'address[]', name: 'fleetCommanders' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'shakeAll',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const
