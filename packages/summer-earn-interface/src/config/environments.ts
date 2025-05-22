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
