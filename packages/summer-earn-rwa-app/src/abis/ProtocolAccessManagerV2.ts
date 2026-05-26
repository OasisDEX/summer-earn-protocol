// V2-only additions on top of ProtocolAccessManager. The base PAM ABI in
// ./ProtocolAccessManager.ts covers role constants, hasRole, grantRole,
// revokeRole, RoleGranted/RoleRevoked, etc. This file adds the V2 surface:
// WHITELIST_MANAGER_ROLE + setWhitelisted/setWhitelistedBatch/setWhitelistOpen
// + isWhitelisted/isWhitelistOpen views + WhitelistStatusUpdated events.

export const protocolAccessManagerV2Abi = [
  // OZ AccessControl primitives — needed for generic grant/revoke by role hash.
  // The base PAM ABI only exposes the typed grantXxxRole helpers, so we add
  // the raw entrypoints here.
  {
    type: 'function',
    name: 'grantRole',
    inputs: [
      { name: 'role', type: 'bytes32', internalType: 'bytes32' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'revokeRole',
    inputs: [
      { name: 'role', type: 'bytes32', internalType: 'bytes32' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'hasRole',
    inputs: [
      { name: 'role', type: 'bytes32', internalType: 'bytes32' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'WHITELIST_MANAGER_ROLE',
    inputs: [],
    outputs: [{ name: '', type: 'bytes32', internalType: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isWhitelisted',
    inputs: [
      { name: 'context', type: 'address', internalType: 'address' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isWhitelistOpen',
    inputs: [{ name: 'context', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'areWhitelisted',
    inputs: [
      { name: 'context', type: 'address', internalType: 'address' },
      { name: 'accounts', type: 'address[]', internalType: 'address[]' },
    ],
    outputs: [{ name: '', type: 'bool[]', internalType: 'bool[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'setWhitelisted',
    inputs: [
      { name: 'context', type: 'address', internalType: 'address' },
      { name: 'account', type: 'address', internalType: 'address' },
      { name: 'allowed', type: 'bool', internalType: 'bool' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setWhitelistedBatch',
    inputs: [
      { name: 'context', type: 'address', internalType: 'address' },
      { name: 'accounts', type: 'address[]', internalType: 'address[]' },
      { name: 'allowed', type: 'bool[]', internalType: 'bool[]' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setWhitelistOpen',
    inputs: [
      { name: 'context', type: 'address', internalType: 'address' },
      { name: 'isOpen', type: 'bool', internalType: 'bool' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'grantWhitelistManagerRole',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'revokeWhitelistManagerRole',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'grantOperatorRole',
    inputs: [
      { name: 'target', type: 'address', internalType: 'address' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'revokeOperatorRole',
    inputs: [
      { name: 'target', type: 'address', internalType: 'address' },
      { name: 'account', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'WhitelistStatusUpdated',
    inputs: [
      { name: 'context', type: 'address', indexed: true, internalType: 'address' },
      { name: 'account', type: 'address', indexed: true, internalType: 'address' },
      { name: 'isWhitelisted', type: 'bool', indexed: false, internalType: 'bool' },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'WhitelistOpenUpdated',
    inputs: [
      { name: 'context', type: 'address', indexed: true, internalType: 'address' },
      { name: 'isOpen', type: 'bool', indexed: false, internalType: 'bool' },
    ],
    anonymous: false,
  },
] as const
