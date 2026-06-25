export const dcaStrategyManagerAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: '_accessManager',
        type: 'address',
        internalType: 'address',
      },
      {
        name: '_ensoRouter',
        type: 'address',
        internalType: 'address',
      },
      {
        name: '_harborCommand',
        type: 'address',
        internalType: 'address',
      },
      {
        name: '_permit2',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'ADMIRALS_QUARTERS_ROLE',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'DECAY_CONTROLLER_ROLE',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'ENSO_ROUTER',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'address',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'GOVERNOR_ROLE',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'GUARDIAN_ROLE',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'HARBOR_COMMAND',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IHarborCommand',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'PERMIT2',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'address',
        internalType: 'contract IPermit2',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'SUPER_KEEPER_ROLE',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'activeCommitments',
    inputs: [
      {
        name: 'commitmentHash',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'bool',
        internalType: 'bool',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'cancelStrategy',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'checkUpkeep',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [
      {
        name: 'upkeepNeeded',
        type: 'bool',
        internalType: 'bool',
      },
      {
        name: 'performData',
        type: 'bytes',
        internalType: 'bytes',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'createStrategy',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'createStrategyWithPermit2',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'permitSingle',
        type: 'tuple',
        internalType: 'struct IAllowanceTransfer.PermitSingle',
        components: [
          {
            name: 'details',
            type: 'tuple',
            internalType: 'struct IAllowanceTransfer.PermitDetails',
            components: [
              {
                name: 'token',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'amount',
                type: 'uint160',
                internalType: 'uint160',
              },
              {
                name: 'expiration',
                type: 'uint48',
                internalType: 'uint48',
              },
              {
                name: 'nonce',
                type: 'uint48',
                internalType: 'uint48',
              },
            ],
          },
          {
            name: 'spender',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sigDeadline',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'signature',
        type: 'bytes',
        internalType: 'bytes',
      },
    ],
    outputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'depositAndCreate',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'assetAmount',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'expectedMinShares',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'depositAndCreateWithPermit2',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'assetAmount',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'permits',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.Permit2DepositBundle',
        components: [
          {
            name: 'inAsset',
            type: 'tuple',
            internalType: 'struct ISignatureTransfer.PermitTransferFrom',
            components: [
              {
                name: 'permitted',
                type: 'tuple',
                internalType: 'struct ISignatureTransfer.TokenPermissions',
                components: [
                  {
                    name: 'token',
                    type: 'address',
                    internalType: 'contract IERC20',
                  },
                  {
                    name: 'amount',
                    type: 'uint256',
                    internalType: 'uint256',
                  },
                ],
              },
              {
                name: 'nonce',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'deadline',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'inAssetSig',
            type: 'bytes',
            internalType: 'bytes',
          },
          {
            name: 'shares',
            type: 'tuple',
            internalType: 'struct IAllowanceTransfer.PermitSingle',
            components: [
              {
                name: 'details',
                type: 'tuple',
                internalType: 'struct IAllowanceTransfer.PermitDetails',
                components: [
                  {
                    name: 'token',
                    type: 'address',
                    internalType: 'address',
                  },
                  {
                    name: 'amount',
                    type: 'uint160',
                    internalType: 'uint160',
                  },
                  {
                    name: 'expiration',
                    type: 'uint48',
                    internalType: 'uint48',
                  },
                  {
                    name: 'nonce',
                    type: 'uint48',
                    internalType: 'uint48',
                  },
                ],
              },
              {
                name: 'spender',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'sigDeadline',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'sharesSig',
            type: 'bytes',
            internalType: 'bytes',
          },
        ],
      },
      {
        name: 'expectedMinShares',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'editStrategy',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'oldConfig',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'newConfig',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'executeStrategy',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
      {
        name: 'ensoData',
        type: 'bytes',
        internalType: 'bytes',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'generateRole',
    inputs: [
      {
        name: 'roleName',
        type: 'uint8',
        internalType: 'enum ContractSpecificRoles',
      },
      {
        name: 'roleTargetContract',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'hasAdmiralsQuartersRole',
    inputs: [
      {
        name: 'account',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'bool',
        internalType: 'bool',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'pauseStrategy',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'resumeStrategy',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'strategyCommitments',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: 'commitmentHash',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'strategyStates',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct IDCAStrategyManager.StrategyState',
        components: [
          {
            name: 'status',
            type: 'uint8',
            internalType: 'enum IDCAStrategyManager.Status',
          },
          {
            name: 'tradesExecuted',
            type: 'uint248',
            internalType: 'uint248',
          },
          {
            name: 'nextTriggerAt',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'lastScheduledAt',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'ExecutionCompleted',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'tradesExecuted',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'inShares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'outShares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'inAssets',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'outAssets',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'nextTriggerAt',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyCancelled',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyCompleted',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'reason',
        type: 'bytes32',
        indexed: false,
        internalType: 'bytes32',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyCreated',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        indexed: false,
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyEdited',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'config',
        type: 'tuple',
        indexed: false,
        internalType: 'struct IDCAStrategyManager.StrategyConfig',
        components: [
          {
            name: 'owner',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'sourceVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'targetVault',
            type: 'address',
            internalType: 'contract IFleetCommander',
          },
          {
            name: 'inAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'outAsset',
            type: 'address',
            internalType: 'contract IERC20',
          },
          {
            name: 'inAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'outAssetFeed',
            type: 'tuple',
            internalType: 'struct ChainlinkFeed',
            components: [
              {
                name: 'feed',
                type: 'address',
                internalType: 'address',
              },
              {
                name: 'maxStaleness',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'tradeAmount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'interval',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'slippageBps',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'minPrice',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'endDate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'maxTrades',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyPaused',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'nextTriggerAt',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'StrategyResumed',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: 'nextTriggerAt',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'AmountOverflowsUint160',
    inputs: [
      {
        name: 'amount',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotAdmin',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotAuthorizedToBoard',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotCommander',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotContractSpecificRole',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'role',
        type: 'bytes32',
        internalType: 'bytes32',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotCurator',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotDecayController',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotFoundation',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotGovernor',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotGuardian',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotGuardianOrGovernor',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotKeeper',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotOperator',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotRaft',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotRaftOrCommander',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'CallerIsNotSuperKeeper',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'ChainlinkOraclePriceZero',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ChainlinkOracleStalePrice',
    inputs: [
      {
        name: 'feed',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'updatedAt',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'currentTime',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'CommitmentMismatch',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'DepositSharesBelowMin',
    inputs: [
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'received',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'DirectGrantIsDisabled',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'DirectRevokeIsDisabled',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'DuplicateStrategy',
    inputs: [],
  },
  {
    type: 'error',
    name: 'EmptySwapData',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ExecutionWindowNotReached',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'nextTriggerAt',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'blockTimestamp',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InAssetVaultMismatch',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'actual',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'InactiveFleetCommander',
    inputs: [
      {
        name: 'vault',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'label',
        type: 'string',
        internalType: 'string',
      },
    ],
  },
  {
    type: 'error',
    name: 'IntervalTooLong',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'maximum',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'IntervalTooShort',
    inputs: [
      {
        name: 'provided',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'minimum',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidAccessManagerAddress',
    inputs: [
      {
        name: 'invalidAddress',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidFeedAddress',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidHarborCommandAddress',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidOwner',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidPermit2Address',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidPermit2Amount',
    inputs: [
      {
        name: 'expected',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'actual',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidPermit2Spender',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'actual',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidPermit2Token',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'actual',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidPriceBounds',
    inputs: [
      {
        name: 'minPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'maxPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'InvalidRouterAddress',
    inputs: [],
  },
  {
    type: 'error',
    name: 'InvalidSlippage',
    inputs: [
      {
        name: 'slippageBps',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'OutAssetVaultMismatch',
    inputs: [
      {
        name: 'expected',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'actual',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'Permit2AllowanceInsufficient',
    inputs: [
      {
        name: 'signed',
        type: 'uint160',
        internalType: 'uint160',
      },
      {
        name: 'required',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'Permit2AllowanceNotSet',
    inputs: [
      {
        name: 'required',
        type: 'uint160',
        internalType: 'uint160',
      },
      {
        name: 'actual',
        type: 'uint160',
        internalType: 'uint160',
      },
    ],
  },
  {
    type: 'error',
    name: 'Permit2ExpirationNotSet',
    inputs: [
      {
        name: 'required',
        type: 'uint48',
        internalType: 'uint48',
      },
      {
        name: 'actual',
        type: 'uint48',
        internalType: 'uint48',
      },
    ],
  },
  {
    type: 'error',
    name: 'Permit2ExpirationTooEarly',
    inputs: [
      {
        name: 'expiration',
        type: 'uint48',
        internalType: 'uint48',
      },
      {
        name: 'endDate',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'PriceAboveCeiling',
    inputs: [
      {
        name: 'executionPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'maxPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'PriceBelowFloor',
    inputs: [
      {
        name: 'executionPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'minPrice',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'ReentrancyGuardReentrantCall',
    inputs: [],
  },
  {
    type: 'error',
    name: 'SafeERC20FailedOperation',
    inputs: [
      {
        name: 'token',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'SameAsset',
    inputs: [
      {
        name: 'asset',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'StrategyNotActive',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'SwapFailed',
    inputs: [],
  },
  {
    type: 'error',
    name: 'SwapOutputBelowMinOut',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'minOut',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'actualOut',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  {
    type: 'error',
    name: 'UnauthorizedAccess',
    inputs: [
      {
        name: 'strategyId',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'UnauthorizedOwner',
    inputs: [
      {
        name: 'caller',
        type: 'address',
        internalType: 'address',
      },
      {
        name: 'owner',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  {
    type: 'error',
    name: 'ZeroDeposit',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ZeroExpectedOutShares',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ZeroMaxTrades',
    inputs: [],
  },
  {
    type: 'error',
    name: 'ZeroTradeAmount',
    inputs: [],
  },
] as const
