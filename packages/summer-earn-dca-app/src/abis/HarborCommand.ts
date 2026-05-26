// Minimal HarborCommand surface used by the FE to enumerate active FleetCommanders
// for the create-strategy vault picker. (Source: packages/core-contracts/src/interfaces/IHarborCommand.sol)

export const harborCommandAbi = [
  {
    type: 'function',
    name: 'activeFleetCommanders',
    stateMutability: 'view',
    inputs: [{ name: 'fleetCommander', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }],
  },
  {
    type: 'function',
    name: 'getActiveFleetCommanders',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
] as const
