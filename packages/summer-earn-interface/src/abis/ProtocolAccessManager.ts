export const protocolAccessManagerAbi = [
  // Role constants
  {
    type: 'function',
    name: 'GOVERNOR_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'SUPER_KEEPER_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'GUARDIAN_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'DECAY_CONTROLLER_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'ADMIRALS_QUARTERS_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'FOUNDATION_ROLE',
    inputs: [],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'view'
  },
  
  // Role management functions
  {
    type: 'function',
    name: 'grantGovernorRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeGovernorRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantSuperKeeperRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeSuperKeeperRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantGuardianRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeGuardianRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantDecayControllerRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeDecayControllerRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantAdmiralsQuartersRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeAdmiralsQuartersRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantFoundationRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeFoundationRole',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  
  // Fleet-specific role management
  {
    type: 'function',
    name: 'grantCuratorRole',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeCuratorRole',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantKeeperRole',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeKeeperRole',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'grantCommanderRole',
    inputs: [
      { type: 'address', name: 'arkAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeCommanderRole',
    inputs: [
      { type: 'address', name: 'arkAddress' },
      { type: 'address', name: 'account' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  
  // Contract-specific role management
  {
    type: 'function',
    name: 'grantContractSpecificRole',
    inputs: [
      { type: 'uint8', name: 'roleName' },
      { type: 'address', name: 'roleTargetContract' },
      { type: 'address', name: 'roleOwner' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'revokeContractSpecificRole',
    inputs: [
      { type: 'uint8', name: 'roleName' },
      { type: 'address', name: 'roleTargetContract' },
      { type: 'address', name: 'roleOwner' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'selfRevokeContractSpecificRole',
    inputs: [
      { type: 'uint8', name: 'roleName' },
      { type: 'address', name: 'roleTargetContract' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  
  // Guardian expiration management
  {
    type: 'function',
    name: 'setGuardianExpiration',
    inputs: [
      { type: 'address', name: 'account' },
      { type: 'uint256', name: 'expiration' }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'isActiveGuardian',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'getGuardianExpiration',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [{ type: 'uint256', name: 'expiration' }],
    stateMutability: 'view'
  },
  
  // Role checking
  {
    type: 'function',
    name: 'hasRole',
    inputs: [
      { type: 'bytes32', name: 'role' },
      { type: 'address', name: 'account' }
    ],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'generateRole',
    inputs: [
      { type: 'uint8', name: 'roleName' },
      { type: 'address', name: 'roleTargetContract' }
    ],
    outputs: [{ type: 'bytes32', name: '' }],
    stateMutability: 'pure'
  },
  
  // Constants
  {
    type: 'function',
    name: 'MIN_GUARDIAN_EXPIRY',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'MAX_GUARDIAN_EXPIRY',
    inputs: [],
    outputs: [{ type: 'uint256', name: '' }],
    stateMutability: 'view'
  },
  
  // Events
  {
    type: 'event',
    name: 'GuardianExpirationSet',
    inputs: [
      { type: 'address', name: 'account', indexed: true },
      { type: 'uint256', name: 'expiration', indexed: false }
    ]
  },
  {
    type: 'event',
    name: 'RoleGranted',
    inputs: [
      { type: 'bytes32', name: 'role', indexed: true },
      { type: 'address', name: 'account', indexed: true },
      { type: 'address', name: 'sender', indexed: true }
    ]
  },
  {
    type: 'event',
    name: 'RoleRevoked',
    inputs: [
      { type: 'bytes32', name: 'role', indexed: true },
      { type: 'address', name: 'account', indexed: true },
      { type: 'address', name: 'sender', indexed: true }
    ]
  },
  
  // Interface support
  {
    type: 'function',
    name: 'supportsInterface',
    inputs: [{ type: 'bytes4', name: 'interfaceId' }],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  }
] as const