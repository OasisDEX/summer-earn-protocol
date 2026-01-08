import { Address } from 'viem'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'viem/chains'

export type Environment = 'production' | 'staging'

export const HARBOR_COMMAND_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [arbitrum.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [base.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [sonic.id]: '0xa8E4716a1e8Db9dD79f1812AF30e073d3f4Cf191',
    [hyperliquid.id]: '0x5CD5D7e3A1b604E0EdeDc4A2343b312729e09E3F',
  },
  staging: {
    [mainnet.id]: '0x07060E282bd0FB99607c8915f1E538F8CebF5FC4',
    [arbitrum.id]: '0x6De9F53c553e1511E1dBBd43E86148868400CbFb',
    [base.id]: '0xE355F38F0144a9f07A1Dc8f95ED23658d96613AF',
    [sonic.id]: '0x5de028b0ED0F1B5A81636eB97445236C6b4b2523',
    [hyperliquid.id]: '0xf5A69789Bf5e62A43C47E4c8d857b8DAE14d4ab0',
  },
}

export const RAFT_CONTRACT_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [arbitrum.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [base.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [sonic.id]: '0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204', // TODO: Add actual address
    [hyperliquid.id]: '0xFF199c0B988f80987e6612a99a024Ec9A6F59f53', // TODO: Add actual address
  },
  staging: {
    [mainnet.id]: '0xceDBFEF8A10c20a96E2309E4Fd31F7D3834eFaF7', // TODO: Add actual address
    [arbitrum.id]: '0xa57EFa57592E00a307477D840B931406921fEF36', // TODO: Add actual address
    [base.id]: '0xB5113dA0CaE7DDf19b8e25103B2F411148b8BAeb', // TODO: Add actual address
    [sonic.id]: '0x702C4114eB8bB23Dd1432bb12Ac51B9cD5C7826f', // TODO: Add actual address
    [hyperliquid.id]: '0xabF2654d149E0fDcCb7e319796D065299376AFcC', // TODO: Add actual address
  },
}

// Token addresses per chain
export const PROTOCOL_ACCESS_MANAGER_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694',
    [arbitrum.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694', // TODO: Add actual address for arbitrum
    [base.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694', // TODO: Add actual address for base
    [sonic.id]: '0xAFb8a8beA8F7CdB4b65437b0c5963dc7Cd270bC6', // TODO: Add actual address for sonic
    [hyperliquid.id]: '0x38fB5a7fa70103dCd9e8A969f3975A77E0fE755f', // TODO: Add actual address for hyperliquid
  },
  staging: {
    [mainnet.id]: '0x092C41C6e9A8A54577CeDe5d077971116DdD6F57', // TODO: Add actual staging address
    [arbitrum.id]: '0x2e208e55075b1cF15A767C15Ee9bA14205CB8371', // TODO: Add actual staging address
    [base.id]: '0x603821f86DeDC794A3225d62Afe1F175fe4AE861', // TODO: Add actual staging address
    [sonic.id]: '0xA55cd6a6D882180E84DDb25F7c7Ae4e4Af0f3f27', // TODO: Add actual staging address
    [hyperliquid.id]: '0xabF2654d149E0fDcCb7e319796D065299376AFcC', // TODO: Add actual staging address
  },
}

// Summer Vesting Wallet Factory addresses per environment/chain
export const SUMMER_VESTING_WALLET_FACTORY_ADDRESSES: Record<
  Environment,
  Record<number, Address>
> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x5f3cd3a45E6B8c2B29DDC80411C58291740E8886',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x7dbc2ac4ad0ac857144475b0e766ca6f76df8937',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

// Summer Vesting Wallet Factory V2 addresses per environment/chain
export const SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES: Record<
  Environment,
  Record<number, Address>
> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x3aA85a023C0e935CDb5d1CBB2d7BC5EAC5c69BeB',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xBceCc704edB1A65b65Ffe6505011f96252a7892B',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const REWARD_TOKENS: Record<number, Address[]> = {
  [sonic.id]: [
    '0xb098AFC30FCE67f1926e735Db6fDadFE433E61db',
    '0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38',
  ],
  // Add other chains as needed
  [mainnet.id]: [],
  [arbitrum.id]: [],
  [base.id]: [],
}

// Intent System Contract Addresses (Base only for now)
export const INTENT_SYSTEM_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [arbitrum.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [base.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [sonic.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [arbitrum.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [base.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
    [sonic.id]: '0x0000000000000000000000000000000000000000', // Not deployed yet
  },
}

// Individual Intent System Contracts (Base staging)
export const INTENT_BOND_FACTORY_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x39a1b82f989BD26552DbF95f0483d8A83654B6FF', // TODO: Add actual deployed address
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const INTENT_HANDLER_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x574972f6948c127d30ac94f9eedA8855C1d0c413', // TODO: Add actual deployed address
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

// Mock Intent Oracle Addresses (for testing)
export const MOCK_INTENT_ORACLE_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x8a6AeCaa8C5241b72bA8c8D5D67102341Ee0c553', // TODO: Add actual deployed address
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

// Intent System Supported Tokens
export const INTENT_SYSTEM_TOKENS: Record<Environment, Record<number, Record<string, string>>> = {
  production: {
    [mainnet.id]: {},
    [arbitrum.id]: {},
    [base.id]: {},
    [sonic.id]: {},
  },
  staging: {
    [mainnet.id]: {},
    [arbitrum.id]: {},
    [base.id]: {
      SUMMER: '0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32',
      USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    },
    [sonic.id]: {},
  },
}

// Summer Staking contracts (Base only for now)
export const SUMMER_TOKEN_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const STAKED_SUMMER_TOKEN_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x7cC488F2681cFC2A5E8A00184bfA94ea6d520D1c',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xcd19c8540421CEd9B09f08F1887951da3F193851',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const SUMMER_STAKING_ADDRESSES: Record<Environment, Record<number, Address>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xcA2e14c7C03C9961c296C89e2d2279F5F7DB15b4',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x6B94fD1Cbf967c6441764a5AcB84eF2B3774c09f',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES: Record<
  Environment,
  Record<number, Address>
> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xdF8b1E08679D6035b6c1504e04C5C9e72a0555Fe',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xD67818c79ef3a8EfB7383fe3Ecc5C55a2221F674',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}
