import { Abi, parseAbiItem } from 'viem'

// Separate string ABIs from Object ABIs to properly maintain internalTypes for Percentage
const KNOWN_STRING_ABIS = [
  'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
  'function grantCuratorRole(address fleetAddress, address account) external',
  'function grantAdmiralsQuartersRole(address account) external',
  'function revokeAdmiralsQuartersRole(address account) external',
  'function grantCommanderRole(address arkAddress, address account) external',
  'function addArk(address ark) external',
  'function enlistFleetCommander(address fleetCommander) external',
  'function grantRole(bytes32 role, address account) external',
  'function revokeRole(bytes32 role, address account) external',
  'function grantGovernorRole(address account) external',
  'function revokeGovernorRole(address account) external',
  'function grantSuperKeeperRole(address account) external',
  'function revokeSuperKeeperRole(address account) external',
  'function grantGuardianRole(address account) external',
  'function revokeGuardianRole(address account) external',
  'function setGuardianExpiration(address account, uint256 expiration) external',
  'function grantDecayControllerRole(address account) external',
  'function revokeDecayControllerRole(address account) external',
  'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
  'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',
  'function setRaft(address raft) external',
  'function sweep(address ark,address[] tokens) external',
  'function sweep(address[] tokens) external',
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function transfer(address to, uint256 amount) external returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) external returns (bool)',
  'function setVotingDelay(uint48 newVotingDelay) external',
  'function setVotingPeriod(uint32 newVotingPeriod) external',
  'function setQuorumNumerator(uint256 newQuorumNumerator) external',
  'function setProposalThreshold(uint256 newProposalThreshold) external',
  'function setProposalMaxOperations(uint256 newProposalMaxOperations) external',
  'function setProposalMaxDuration(uint256 newProposalMaxDuration) external',
  'function updateDelay(uint256 newDelay) external',
  'function addToWhitelist(address account) external',
  'function setFleetTokenTransferability() external',
  'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  'function scheduleBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  'function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public payable',
  'function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public payable',
  'function cancel(bytes32 id) public',
  'function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  'function hashOperationBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  'function hasRole(bytes32 role, address account) public view returns (bool)',
  'function castVote(uint256 proposalId, uint8 support) public returns (uint256)',
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
  'function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public returns (uint256)',
  'function createCampaign((bytes32 campaignId, address creator, address rewardToken, uint256 amount, uint32 campaignType, uint32 startTimestamp, uint32 duration, bytes campaignData)) external returns (uint256)',
  'function setNonSweepableToken(address ark, address token, bool isNonSweepable) external',
  'function validateTimestamp() external',
  'function removeRoot(uint256 index) external',
  'function mint(address to, uint256 amount) external',
  'function burn(address from, uint256 amount) external',
]

const KNOWN_OBJECT_ABIS = [
  {
    type: 'function',
    name: 'send',
    inputs: [
      {
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
        name: 'sendParams',
        type: 'tuple',
      },
      {
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ],
        name: 'feeParams',
        type: 'tuple',
      },
      { name: '_refundAddress', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'external',
  },
  {
    type: 'function',
    name: 'setTipRate',
    inputs: [
      {
        name: 'newTipRate',
        type: 'uint256',
        internalType: 'Percentage',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'addTipStream',
    inputs: [
      {
        name: 'tipStream',
        type: 'tuple',
        internalType: 'struct ITipJar.TipStream',
        components: [
          { name: 'recipient', type: 'address', internalType: 'address' },
          { name: 'allocation', type: 'uint256', internalType: 'Percentage' },
          { name: 'lockedUntilEpoch', type: 'uint256', internalType: 'uint256' },
        ],
      },
    ],
    outputs: [{ name: 'lockedUntilEpoch', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'nonpayable',
  },
] as const

// Unified ABI containing both formatted objects and parsed strings
export const COMBINED_ABI: Abi = [
  ...KNOWN_STRING_ABIS.map((sig) => parseAbiItem(sig)),
  ...KNOWN_OBJECT_ABIS,
] as Abi
