import { parseAbiItem } from 'viem'

// Standard OpenZeppelin Governor events
export const GOVERNOR_EVENTS = [
  parseAbiItem('event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)'),
  parseAbiItem('event ProposalQueued(uint256 proposalId, uint256 eta)'),
  parseAbiItem('event ProposalExecuted(uint256 proposalId)'),
  parseAbiItem('event ProposalCanceled(uint256 proposalId)'),
  parseAbiItem('event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)'),
  parseAbiItem('event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)'),
]

// Standard OpenZeppelin TimelockController events
export const TIMELOCK_EVENTS = [
  parseAbiItem('event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)'),
  parseAbiItem('event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)'),
  parseAbiItem('event Cancelled(bytes32 indexed id)'),
  parseAbiItem('event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)'),
  parseAbiItem('event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)'),
]
