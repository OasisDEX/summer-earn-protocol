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
