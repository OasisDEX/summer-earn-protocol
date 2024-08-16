import { default as dotenv } from 'dotenv'
import { resolve } from 'path'

// WARNING: Do not move the loading of the .env as the import for `getHardhatConfig`
// needs the variables to be preloaded
dotenv.config({ path: resolve(__dirname, './.env') })

import type { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-ignition-viem'

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.26',
    settings: {
      viaIR: true,
    },
  },
  paths: {
    sources: './src',
  },
  networks: {
    local: {
      url: `http://127.0.0.1:8545`,
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
    },
    // optimism: {},
    // arbitrum: {},
    base: {
      url: `${process.env.BASE_RPC_URL}`,
      accounts: [`0x${process.env.DEPLOYER_PRIV_KEY}`],
    },

    // testnets
    // sepolia_mainnet: {},
    // sepolia_optimism: {},
    // sepolia_arbitrum: {},
    // sepolia_base: {}
  },
}

export default config
