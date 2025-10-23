export const GenericIntentArkABI = [
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "string",
            "name": "name",
            "type": "string"
          },
          {
            "internalType": "string",
            "name": "details",
            "type": "string"
          },
          {
            "internalType": "address",
            "name": "accessManager",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "configurationManager",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "asset",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "depositCap",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxRebalanceOutflow",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxRebalanceInflow",
            "type": "uint256"
          },
          {
            "internalType": "bool",
            "name": "requiresKeeperData",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "maxDepositPercentageOfTVL",
            "type": "uint256"
          }
        ],
        "internalType": "struct ArkParams",
        "name": "_params",
        "type": "tuple"
      },
      {
        "internalType": "address",
        "name": "_intentHandler",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_intentBondFactory",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "intentId",
        "type": "bytes32"
      },
      {
        "internalType": "uint256",
        "name": "requiredNotional",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "term",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "targetYield",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "summerToken",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "oracle",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "expiry",
        "type": "uint256"
      }
    ],
    "name": "postIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "intentId",
        "type": "bytes32"
      }
    ],
    "name": "cancelIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "intentId",
        "type": "bytes32"
      }
    ],
    "name": "isIntentActive",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "intentId",
        "type": "bytes32"
      }
    ],
    "name": "getIntent",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "requiredNotional",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "term",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "targetYield",
            "type": "uint256"
          },
          {
            "internalType": "address",
            "name": "token",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "oracle",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "expiry",
            "type": "uint256"
          },
          {
            "internalType": "address",
            "name": "solver",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "escrowedYield",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "startTime",
            "type": "uint256"
          },
          {
            "internalType": "enum IIntentHandler.IntentState",
            "name": "state",
            "type": "uint8"
          }
        ],
        "internalType": "struct IIntentHandler.Intent",
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "intentHandler",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "intentBondFactory",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "config",
    "outputs": [
      {
        "components": [
          {
            "internalType": "string",
            "name": "name",
            "type": "string"
          },
          {
            "internalType": "string",
            "name": "details",
            "type": "string"
          },
          {
            "internalType": "address",
            "name": "accessManager",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "configurationManager",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "asset",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "depositCap",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxRebalanceOutflow",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "maxRebalanceInflow",
            "type": "uint256"
          },
          {
            "internalType": "bool",
            "name": "requiresKeeperData",
            "type": "bool"
          },
          {
            "internalType": "uint256",
            "name": "maxDepositPercentageOfTVL",
            "type": "uint256"
          }
        ],
        "internalType": "struct ArkParams",
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
] as const
