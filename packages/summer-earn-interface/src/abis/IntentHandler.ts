export const IntentHandlerABI = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_intentBondFactory",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_intentOracle",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_summerToken",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "_accessManager",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "requiredNotional",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "requiredBond",
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      }
    ],
    "name": "createIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "requiredNotional",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "requiredBond",
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      },
      {
        "internalType": "uint256",
        "name": "escrowedYield",
        "type": "uint256"
      }
    ],
    "name": "solveIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      },
      {
        "internalType": "uint256",
        "name": "exscrowedYield",
        "type": "uint256" 
      }
    ],
    "name": "settleIntent",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      }
    ],
    "name": "resignByUser",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      }
    ],
    "name": "resignBySolver",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "solver",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "asset",
        "type": "address"
      }
    ],
    "name": "addSolverEscrow",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "solver",
        "type": "address"
      }
    ],
    "name": "removeSolverEscrow",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "user",
            "type": "address"
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
          }
        ],
        "internalType": "IIntentHandler.Intent",
        "name": "intent",
        "type": "tuple"
      }
    ],
    "name": "hasCommitted",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "requiredNotional",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "arkAssets",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "isCommited",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "MAX_PRICE_AGE",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "MIN_TERM",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "MAX_TERM",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "BUFFER_TIME",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "name": "intentStates",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "solverEscrows",
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
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "name": "intentSolvers",
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
    "inputs": [
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "name": "intentSolveTime",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
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
        "internalType": "contract IIntentBondFactory",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "intentOracle",
    "outputs": [
      {
        "internalType": "contract IIntentOracle",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "summerToken",
    "outputs": [
      {
        "internalType": "contract IERC20",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "accessManager",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
