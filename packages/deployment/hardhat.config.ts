import { default as dotenv } from 'dotenv'
import { resolve } from 'path'

import '@nomicfoundation/hardhat-verify'
import 'hardhat-contract-sizer'
import './plugins/multiSourceCompile'

dotenv.config({ path: resolve(__dirname, '../../.env') })

import type { HardhatUserConfig } from 'hardhat/config'

import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-ignition-viem'

if (!process.env.API_KEY_ETHERSCAN) {
  throw new Error(
    'Please set your process.env.API_KEY_ETHERSCAN in a .env file ( etherscan v2 api key )',
  )
}

const config: HardhatUserConfig = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: process.env.REPORT_CONTRACT_SIZE === 'true',
    strict: false,
  },
  etherscan: {
    apiKey: process.env.API_KEY_ETHERSCAN,
    customChains: [
      {
        network: 'sonic',
        chainId: 146,
        urls: {
          apiURL: `https://api.sonicscan.org/api`,
          browserURL: `https://sonicscan.org`,
        },
      },
      {
        network: 'unichain',
        chainId: 130,
        urls: {
          apiURL: `https://api.unichainscan.org/api`,
          browserURL: `https://uniscan.xyz`,
        },
      },
      {
        network: 'hyperliquid',
        chainId: 999,
        urls: {
          apiURL: `https://api.etherscan.io/api`,
          browserURL: `https://hyperevmscan.io/`,
        },
      },
    ],
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
        runs: 25,
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
    unichain: {
      url: `${process.env.UNICHAIN_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 130,
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
    sonic: {
      url: `${process.env.SONIC_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 146,
    },
    monad: {
      url: `${process.env.MONAD_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 143,
    },
    hyperliquid: {
      url: `${process.env.HYPERLIQUID_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
      chainId: 999,
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
