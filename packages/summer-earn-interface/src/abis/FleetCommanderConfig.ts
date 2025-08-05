export const fleetCommanderConfigAbi = [
  {
    type: 'function',
    name: 'config',
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
  },{"type":"function","name":"getConfig","inputs":[],"outputs":[{"name":"","type":"tuple","internalType":"struct FleetConfig","components":[{"name":"bufferArk","type":"address","internalType":"contract IArk"},{"name":"minimumBufferBalance","type":"uint256","internalType":"uint256"},{"name":"depositCap","type":"uint256","internalType":"uint256"},{"name":"maxRebalanceOperations","type":"uint256","internalType":"uint256"},{"name":"stakingRewardsManager","type":"address","internalType":"address"}]}],"stateMutability":"view"}
] as const