export const IAccountGuardAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'previousOwner', type: 'address' },
      { indexed: true, internalType: 'address', name: 'newOwner', type: 'address' },
    ],
    name: 'OwnershipTransferred',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'caller', type: 'address' },
      { indexed: true, internalType: 'address', name: 'proxy', type: 'address' },
    ],
    name: 'PermissionGranted',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'caller', type: 'address' },
      { indexed: true, internalType: 'address', name: 'proxy', type: 'address' },
    ],
    name: 'PermissionRevoked',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'newOwner', type: 'address' },
      { indexed: true, internalType: 'address', name: 'oldAddress', type: 'address' },
      { indexed: true, internalType: 'address', name: 'proxy', type: 'address' },
    ],
    name: 'ProxyOwnershipTransferred',
    type: 'event',
  },
  {
    inputs: [
      { internalType: 'address', name: 'target', type: 'address' },
      { internalType: 'address', name: 'operator', type: 'address' },
    ],
    name: 'canCall',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'proxy', type: 'address' },
      { internalType: 'address', name: 'operator', type: 'address' },
      { internalType: 'address', name: 'callTarget', type: 'address' },
      { internalType: 'bool', name: 'asDelegateCall', type: 'bool' },
    ],
    name: 'canCallAndWhitelisted',
    outputs: [
      { internalType: 'bool', name: '', type: 'bool' },
      { internalType: 'bool', name: '', type: 'bool' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'newOwner', type: 'address' },
      { internalType: 'address', name: 'target', type: 'address' },
    ],
    name: 'changeOwner',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'initializeFactory',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'target', type: 'address' }],
    name: 'isWhitelisted',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'target', type: 'address' }],
    name: 'isWhitelistedSend',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'owner',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: '', type: 'address' }],
    name: 'owners',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'caller', type: 'address' },
      { internalType: 'address', name: 'target', type: 'address' },
      { internalType: 'bool', name: 'allowance', type: 'bool' },
    ],
    name: 'permit',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'target', type: 'address' },
      { internalType: 'bool', name: 'status', type: 'bool' },
    ],
    name: 'setWhitelist',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'target', type: 'address' },
      { internalType: 'bool', name: 'status', type: 'bool' },
    ],
    name: 'setWhitelistSend',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'newOwner', type: 'address' }],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
]

export const IAccountImplementationAbi = [
  {
    inputs: [{ internalType: 'contract AccountGuard', name: '_guard', type: 'address' }],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: false, internalType: 'address', name: 'sender', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'FundsRecived',
    type: 'event',
  },
  {
    inputs: [
      { internalType: 'address', name: '_target', type: 'address' },
      { internalType: 'bytes', name: '_data', type: 'bytes' },
    ],
    name: 'execute',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'guard',
    outputs: [{ internalType: 'contract AccountGuard', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'owner',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: '_target', type: 'address' },
      { internalType: 'bytes', name: '_data', type: 'bytes' },
    ],
    name: 'send',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  { stateMutability: 'payable', type: 'receive' },
]
