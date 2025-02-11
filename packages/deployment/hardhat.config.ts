import '@nomicfoundation/hardhat-verify'
import { default as dotenv } from 'dotenv'
import 'hardhat-contract-sizer'
import { resolve } from 'path'
// import './plugins/multiSourceCompile'

dotenv.config({ path: resolve(__dirname, '../../.env') })

import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-ignition-viem'
import type { HardhatUserConfig } from 'hardhat/config'

if (!process.env.API_KEY_ARBISCAN) {
  throw new Error('Please set your process.env.API_KEY_ARBISCAN in a .env file')
}
if (!process.env.API_KEY_BASESCAN) {
  throw new Error('Please set your process.env.API_KEY_BASESCAN in a .env file')
}

if (!process.env.API_KEY_ETHERSCAN) {
  throw new Error('Please set your process.env.API_KEY_ETHERSCAN in a .env file')
}

const config: HardhatUserConfig = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: process.env.REPORT_CONTRACT_SIZE === 'true',
    strict: false,
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.API_KEY_ARBISCAN,
      base: process.env.API_KEY_BASESCAN,
      mainnet: process.env.API_KEY_ETHERSCAN,
    },
  },
  ignition: {
    blockPollingInterval: 1_000,
    requiredConfirmations: 1,
  },
  solidity: {
    version: '0.8.28',
    settings: {
      optimizer: {
        enabled: true,
        runs: 50,
      },
      evmVersion: 'cancun',
      viaIR: true,
    },
  },
  networks: {
    local: {
      url: `http://127.0.0.1:8545`,
      chainId: 31337,
    },
    hardhat: {
      accounts: [
        {
          privateKey: `0x${process.env.DEPLOYER_PRIV_KEY}`,
          balance: '1000000000000000000000', // 1000 ETH in wei
        },
      ],
    },
    // mainnets
    mainnet: {
      url: `${process.env.MAINNET_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 1,
    },
    optimism: {
      url: `${process.env.OPTIMISM_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 10,
    },
    arbitrum: {
      url: `${process.env.ARBITRUM_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 42161,
    },
    base: {
      url: `${process.env.BASE_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 8453,
    },

    // testnets
    sepolia_mainnet: {
      url: `${process.env.SEPOLIA_MAINNET_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
    },
    sepolia_optimism: {
      url: `${process.env.SEPOLIA_OPTIMISM_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
    },
    sepolia_arbitrum: {
      url: `${process.env.SEPOLIA_ARBITRUM_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
    },
    sepolia_base: {
      url: `${process.env.SEPOLIA_BASE_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
    },
  },
}

export default config
