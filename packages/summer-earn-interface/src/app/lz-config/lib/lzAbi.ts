export const LZ_ENDPOINT_ABI = [
  // getConfig(address oapp, address lib, uint32 eid, uint32 configType) returns bytes
  {
    type: 'function',
    name: 'getConfig',
    stateMutability: 'view',
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'lib', type: 'address' },
      { name: 'eid', type: 'uint32' },
      { name: 'configType', type: 'uint32' },
    ],
    outputs: [{ name: '', type: 'bytes' }],
  },
  // setConfig(address oapp, address lib, SetConfigParam[] params)
  {
    type: 'function',
    name: 'setConfig',
    stateMutability: 'nonpayable',
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
    outputs: [],
  },
  // getSendLibrary(address sender, uint32 eid) returns address
  {
    type: 'function',
    name: 'getSendLibrary',
    stateMutability: 'view',
    inputs: [
      { name: 'sender', type: 'address' },
      { name: 'eid', type: 'uint32' },
    ],
    outputs: [{ name: '', type: 'address' }],
  },
  // getReceiveLibrary(address receiver, uint32 eid) returns (address lib, bool isDefault)
  {
    type: 'function',
    name: 'getReceiveLibrary',
    stateMutability: 'view',
    inputs: [
      { name: 'receiver', type: 'address' },
      { name: 'eid', type: 'uint32' },
    ],
    outputs: [
      { name: 'lib', type: 'address' },
      { name: 'isDefault', type: 'bool' },
    ],
  },
  // setSendLibrary(address oapp, uint32 eid, address newLib)
  {
    type: 'function',
    name: 'setSendLibrary',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'eid', type: 'uint32' },
      { name: 'newLib', type: 'address' },
    ],
    outputs: [],
  },
  // setReceiveLibrary(address oapp, uint32 eid, address newLib, uint256 gracePeriod)
  {
    type: 'function',
    name: 'setReceiveLibrary',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'eid', type: 'uint32' },
      { name: 'newLib', type: 'address' },
      { name: 'gracePeriod', type: 'uint256' },
    ],
    outputs: [],
  },
  // delegates(address oapp) -> address
  {
    type: 'function',
    name: 'delegates',
    stateMutability: 'view',
    inputs: [{ name: 'oapp', type: 'address' }],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

export const OAPP_ABI = [
  // peers(uint32) -> bytes32
  {
    type: 'function',
    name: 'peers',
    stateMutability: 'view',
    inputs: [{ name: 'eid', type: 'uint32' }],
    outputs: [{ name: '', type: 'bytes32' }],
  },
  // setPeer(uint32 eid, bytes32 peer)
  {
    type: 'function',
    name: 'setPeer',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'eid', type: 'uint32' },
      { name: 'peer', type: 'bytes32' },
    ],
    outputs: [],
  },
  // owner() -> address
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  // enforcedOptions(uint32 eid, uint16 msgType) -> bytes
  {
    type: 'function',
    name: 'enforcedOptions',
    stateMutability: 'view',
    inputs: [
      { name: 'eid', type: 'uint32' },
      { name: 'msgType', type: 'uint16' },
    ],
    outputs: [{ name: '', type: 'bytes' }],
  },
  // setDelegate(address delegate)
  {
    type: 'function',
    name: 'setDelegate',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'delegate', type: 'address' }],
    outputs: [],
  },
  // setEnforcedOptions(EnforcedOptionParam[] params)
  {
    type: 'function',
    name: 'setEnforcedOptions',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'params',
        type: 'tuple[]',
        components: [
          { name: 'eid', type: 'uint32' },
          { name: 'msgType', type: 'uint16' },
          { name: 'options', type: 'bytes' },
        ],
      },
    ],
    outputs: [],
  },
] as const

export const CONFIG_TYPE_EXECUTOR = 1 as const
export const CONFIG_TYPE_ULN = 2 as const

export const MSG_TYPE_SEND = 1 as const
export const MSG_TYPE_SEND_AND_CALL = 2 as const
