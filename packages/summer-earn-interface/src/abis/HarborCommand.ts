export const harborCommandAbi = [
  {
    type: 'function',
    name: 'getActiveFleetCommanders',
    inputs: [],
    outputs: [{ type: 'address[]', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'activeFleetCommanders',
    inputs: [{ type: 'address', name: '_fleetCommander' }],
    outputs: [{ type: 'bool', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'fleetCommandersList',
    inputs: [{ type: 'uint256', name: 'index' }],
    outputs: [{ type: 'address', name: '' }],
    stateMutability: 'view'
  },
  {
    type: 'function',
    name: 'enlistFleetCommander',
    inputs: [{ type: 'address', name: '_fleetCommander' }],
    outputs: [],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'decommissionFleetCommander',
    inputs: [{ type: 'address', name: '_fleetCommander' }],
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const; 