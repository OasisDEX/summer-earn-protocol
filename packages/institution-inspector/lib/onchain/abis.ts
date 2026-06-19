// Minimal ABI subsets for on-chain verification (Pass B).

export const REGISTRY_ABI = [
  {
    type: 'function',
    name: 'exists',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [{ type: 'bool' }],
  },
  {
    type: 'function',
    name: 'getInstitution',
    stateMutability: 'view',
    inputs: [{ name: 'id', type: 'bytes32' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'configurationManager', type: 'address' },
          { name: 'protocolAccessManager', type: 'address' },
          { name: 'admiralsQuarters', type: 'address' },
        ],
      },
    ],
  },
] as const

export const PAM_ABI = [
  {
    type: 'function',
    name: 'hasRole',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
] as const

export const ROUNDS_VAULT_REGISTRY_ABI = [
  {
    type: 'function',
    name: 'getPairByTarget',
    stateMutability: 'view',
    inputs: [{ name: 'targetVault', type: 'address' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'inputVault', type: 'address' },
          { name: 'outputVault', type: 'address' },
          { name: 'targetVault', type: 'address' },
          { name: 'institutionId', type: 'bytes32' },
          { name: 'active', type: 'bool' },
          { name: 'registeredAt', type: 'uint64' },
        ],
      },
    ],
  },
] as const
