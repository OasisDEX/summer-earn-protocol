export const LZ_ENDPOINT_ABI = [
  {
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'lib', type: 'address' },
      {
        name: 'params',
        type: 'tuple[]',
        components: [
          { name: 'eid', type: 'uint32' },
          { name: 'configType', type: 'uint32' },
          { name: 'config', type: 'bytes' },
        ],
      },
    ],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'lib', type: 'address' },
      { name: 'eid', type: 'uint32' },
      { name: 'configType', type: 'uint32' },
    ],
    name: 'getConfig',
    outputs: [{ name: '', type: 'bytes' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'oapp', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: 'delegate', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'eid', type: 'uint32' },
    ],
    name: 'getPeer',
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const
