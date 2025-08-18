import { arbitrum, base, mainnet, sonic } from 'viem/chains'

export type Environment = 'production' | 'staging'

export const HARBOR_COMMAND_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [arbitrum.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [base.id]: '0x09eb323dBFECB43fd746c607A9321dACdfB0140F',
    [sonic.id]: '0xa8E4716a1e8Db9dD79f1812AF30e073d3f4Cf191',
  },
  staging: {
    [mainnet.id]: '0x07060E282bd0FB99607c8915f1E538F8CebF5FC4',
    [arbitrum.id]: '0x6De9F53c553e1511E1dBBd43E86148868400CbFb',
    [base.id]: '0xE355F38F0144a9f07A1Dc8f95ED23658d96613AF',
    [sonic.id]: '0x5de028b0ED0F1B5A81636eB97445236C6b4b2523',
  },
}

export const RAFT_CONTRACT_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [arbitrum.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [base.id]: '0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E', // TODO: Add actual address
    [sonic.id]: '0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204', // TODO: Add actual address
  },
  staging: {
    [mainnet.id]: '0xceDBFEF8A10c20a96E2309E4Fd31F7D3834eFaF7', // TODO: Add actual address
    [arbitrum.id]: '0xa57EFa57592E00a307477D840B931406921fEF36', // TODO: Add actual address
    [base.id]: '0xB5113dA0CaE7DDf19b8e25103B2F411148b8BAeb', // TODO: Add actual address
    [sonic.id]: '0x702C4114eB8bB23Dd1432bb12Ac51B9cD5C7826f', // TODO: Add actual address
  },
}

// Token addresses per chain
export const PROTOCOL_ACCESS_MANAGER_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694',
    [arbitrum.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694', // TODO: Add actual address for arbitrum
    [base.id]: '0xf389BCEa078acD9516414F5dabE3dDd5f7e39694', // TODO: Add actual address for base
    [sonic.id]: '0xAFb8a8beA8F7CdB4b65437b0c5963dc7Cd270bC6', // TODO: Add actual address for sonic
  },
  staging: {
    [mainnet.id]: '0x092C41C6e9A8A54577CeDe5d077971116DdD6F57', // TODO: Add actual staging address
    [arbitrum.id]: '0x2e208e55075b1cF15A767C15Ee9bA14205CB8371', // TODO: Add actual staging address
    [base.id]: '0x603821f86DeDC794A3225d62Afe1F175fe4AE861', // TODO: Add actual staging address
    [sonic.id]: '0xA55cd6a6D882180E84DDb25F7c7Ae4e4Af0f3f27', // TODO: Add actual staging address
  },
}

// Summer Vesting Wallet Factory addresses per environment/chain
export const SUMMER_VESTING_WALLET_FACTORY_ADDRESSES: Record<
  Environment,
  Record<number, string>
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
    [base.id]: '0x5f3cd3a45E6B8c2B29DDC80411C58291740E8886',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const REWARD_TOKENS: Record<number, string[]> = {
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
export const INTENT_SYSTEM_ADDRESSES: Record<Environment, Record<number, string>> = {
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
export const INTENT_BOND_FACTORY_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xe3C4672bd8f87c2147061955c101d66b1DFc5bA2', // Deployed
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const INTENT_HANDLER_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xFBAFa4Ac4e9A99fdd3cC08b1465989568B700089', // Deployed
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const GENERIC_INTENT_ARK_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xaD229B5a3f92A9Eb209e1109433feB330F18f569', // Deployed
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const AAVE_V3_ESCROW_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0xB0bb9518D8E702e6C68eA139D78977199a01493d', // Deployed
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

export const MOCK_INTENT_ORACLE_ADDRESSES: Record<Environment, Record<number, string>> = {
  production: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x0000000000000000000000000000000000000000',
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
  staging: {
    [mainnet.id]: '0x0000000000000000000000000000000000000000',
    [arbitrum.id]: '0x0000000000000000000000000000000000000000',
    [base.id]: '0x58313E1fC9f1f3Ec758C01a715BF3Bc4Cda3b014', // Deployed
    [sonic.id]: '0x0000000000000000000000000000000000000000',
  },
}

// Token addresses for Intent System
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
      USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      SUMMER_TOKEN: '0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32',
    },
    [sonic.id]: {},
  },
}
