// Stargate Adapter ABIs
export const STARGATE_ADD_SUPPORTED_CHAIN_ABI = [
  {
    inputs: [
      { internalType: 'uint16', name: 'chainId', type: 'uint16' },
      { internalType: 'uint32', name: 'endpointId', type: 'uint32' },
      { internalType: 'address', name: 'adapterAddress', type: 'address' },
    ],
    name: 'addSupportedChain',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const STARGATE_ADD_SUPPORTED_ASSET_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'asset', type: 'address' },
      { internalType: 'address', name: 'stargateContract', type: 'address' },
    ],
    name: 'addSupportedAsset',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const STARGATE_UPDATE_CHAIN_ADAPTER_ABI = [
  {
    inputs: [
      { internalType: 'uint16', name: 'chainId', type: 'uint16' },
      { internalType: 'address', name: 'adapterAddress', type: 'address' },
    ],
    name: 'updateChainAdapter',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

// LayerZero Adapter ABIs
export const LAYERZERO_ACTIVATE_READ_CHANNEL_ABI = [
  {
    inputs: [{ internalType: 'uint32', name: 'channelId', type: 'uint32' }],
    name: 'activateReadChannel',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const LAYERZERO_CONFIGURE_READ_LIBRARIES_ABI = [
  {
    inputs: [{ internalType: 'address', name: 'readLib1002Address', type: 'address' }],
    name: 'configureReadLibraries',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const LAYERZERO_CONFIGURE_READ_DVNS_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'readLib1002Address', type: 'address' },
      { internalType: 'address[]', name: 'readDVNs', type: 'address[]' },
      { internalType: 'address', name: 'executor', type: 'address' },
    ],
    name: 'configureReadDVNs',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const LAYERZERO_SET_MIN_GAS_LIMIT_ABI = [
  {
    inputs: [
      { internalType: 'uint16', name: 'msgType', type: 'uint16' },
      { internalType: 'uint128', name: 'gasLimit', type: 'uint128' },
    ],
    name: 'setMinGasLimit',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

export const LAYERZERO_SET_PEER_ABI = [
  {
    inputs: [
      { internalType: 'uint32', name: '_eid', type: 'uint32' },
      { internalType: 'bytes32', name: '_peer', type: 'bytes32' },
    ],
    name: 'setPeer',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

// Bridge Router ABI
export const BRIDGE_ROUTER_REGISTER_ADAPTER_ABI = [
  {
    inputs: [{ internalType: 'address', name: 'adapter', type: 'address' }],
    name: 'registerAdapter',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

// Stargate Contract Validation ABIs
export const STARGATE_POOL_ABI = [
  {
    inputs: [],
    name: 'token',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export const STARGATE_OFT_ABI = [
  {
    inputs: [],
    name: 'stargateType',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export const STARGATE_COMMON_ABI = [
  {
    inputs: [],
    name: 'localDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'sharedDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const
