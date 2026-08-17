import { getNormalizedChainInfo } from '@/config/chains'

describe('getNormalizedChainInfo', () => {
  it('correctly normalizes Hyperliquid/HyperEVM chain inputs', () => {
    expect(getNormalizedChainInfo('999')).toEqual({
      chainId: 999,
      networkName: 'hyperliquid',
    })
    expect(getNormalizedChainInfo('hyperevm')).toEqual({
      chainId: 999,
      networkName: 'hyperliquid',
    })
    expect(getNormalizedChainInfo('HyperEVM')).toEqual({
      chainId: 999,
      networkName: 'hyperliquid',
    })
    expect(getNormalizedChainInfo('hyperliquid')).toEqual({
      chainId: 999,
      networkName: 'hyperliquid',
    })
    expect(getNormalizedChainInfo('HyperLiquid')).toEqual({
      chainId: 999,
      networkName: 'hyperliquid',
    })
  })

  it('correctly normalizes Arbitrum, Base, Mainnet, and Sonic inputs', () => {
    expect(getNormalizedChainInfo('42161')).toEqual({
      chainId: 42161,
      networkName: 'arbitrum',
    })
    expect(getNormalizedChainInfo('arbitrum')).toEqual({
      chainId: 42161,
      networkName: 'arbitrum',
    })
    expect(getNormalizedChainInfo('8453')).toEqual({
      chainId: 8453,
      networkName: 'base',
    })
    expect(getNormalizedChainInfo('base')).toEqual({
      chainId: 8453,
      networkName: 'base',
    })
    expect(getNormalizedChainInfo('146')).toEqual({
      chainId: 146,
      networkName: 'sonic',
    })
    expect(getNormalizedChainInfo('sonic')).toEqual({
      chainId: 146,
      networkName: 'sonic',
    })
    expect(getNormalizedChainInfo('1')).toEqual({
      chainId: 1,
      networkName: 'mainnet',
    })
    expect(getNormalizedChainInfo('mainnet')).toEqual({
      chainId: 1,
      networkName: 'mainnet',
    })
    expect(getNormalizedChainInfo('ethereum')).toEqual({
      chainId: 1,
      networkName: 'mainnet',
    })
  })

  it('handles invalid or empty inputs gracefully', () => {
    expect(getNormalizedChainInfo('')).toEqual({
      chainId: NaN,
      networkName: undefined,
    })
    expect(getNormalizedChainInfo('unknown-chain')).toEqual({
      chainId: NaN,
      networkName: undefined,
    })
  })
})
