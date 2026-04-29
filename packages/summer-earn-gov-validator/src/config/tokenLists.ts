import { SupportedChainId, TokenInfo } from './constants'

export const TOKEN_LISTS: Record<SupportedChainId, TokenInfo[]> = {
  1: [
    {
      address: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
      name: 'Summer',
      symbol: 'SUMMER',
      decimals: 18,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x194f360D130F2393a5E9F3117A6a1B78aBEa1624/logo-128.png',
    },
    {
      address: '0xdc035d45d973e3ec169d2276ddab16f1e407384f',
      name: 'USDS',
      symbol: 'USDS',
      decimals: 18,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0xdc035d45d973e3ec169d2276ddab16f1e407384f/logo-128.png',
    },
    {
      address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo-128.png',
    },
    {
      address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      name: 'Tether USD',
      symbol: 'USDT',
      decimals: 6,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0xdAC17F958D2ee523a2206206994597C13D831ec7/logo-128.png',
    },
    {
      address: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
      name: 'Dai Stablecoin',
      symbol: 'DAI',
      decimals: 18,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo-128.png',
    },
    {
      address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      name: 'Wrapped Ether',
      symbol: 'WETH',
      decimals: 18,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo-128.png',
    },
    {
      address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
      name: 'Wrapped BTC',
      symbol: 'WBTC',
      decimals: 8,
      chainId: 1,
      logoURI:
        'https://assets.smold.app/api/token/1/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599/logo-128.png',
    },
  ],
  8453: [
    {
      address: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
      name: 'Summer',
      symbol: 'SUMMER',
      decimals: 18,
      chainId: 8453,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x194f360D130F2393a5E9F3117A6a1B78aBEa1624/logo-128.png',
    },
    {
      address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      chainId: 8453,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913/logo-128.png',
    },
    {
      address: '0x4200000000000000000000000000000000000006',
      name: 'Wrapped Ether',
      symbol: 'WETH',
      decimals: 18,
      chainId: 8453,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x4200000000000000000000000000000000000006/logo-128.png',
    },
    {
      address: '0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb',
      name: 'Dai Stablecoin',
      symbol: 'DAI',
      decimals: 18,
      chainId: 8453,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb/logo-128.png',
    },
  ],
  42161: [
    {
      address: '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624',
      name: 'Summer',
      symbol: 'SUMMER',
      decimals: 18,
      chainId: 42161,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x194f360D130F2393a5E9F3117A6a1B78aBEa1624/logo-128.png',
    },
    {
      address: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      chainId: 42161,
      logoURI:
        'https://assets.smold.app/api/token/42161/0xaf88d065e77c8cc2239327c5edb3a432268e5831/logo-128.png',
    },
    {
      address: '0x82aF49447D8a07E3bd95BD0d56f35241523fBab1',
      name: 'Wrapped Ether',
      symbol: 'WETH',
      decimals: 18,
      chainId: 42161,
      logoURI:
        'https://assets.smold.app/api/token/42161/0x82aF49447D8a07E3bd95BD0d56f35241523fBab1/logo-128.png',
    },
    {
      address: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
      name: 'Dai Stablecoin',
      symbol: 'DAI',
      decimals: 18,
      chainId: 42161,
      logoURI:
        'https://assets.smold.app/api/token/42161/0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1/logo-128.png',
    },
  ],
  146: [
    {
      address: '0x4e0037f487bBb588bf1B7a83BDe6c34FeD6099e3',
      name: 'Summer',
      symbol: 'SUMMER',
      decimals: 18,
      chainId: 146,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x194f360D130F2393a5E9F3117A6a1B78aBEa1624/logo-128.png',
    },
    {
      address: '0x29219dd400f2Bf60E5a23d13Be72B486D4038894',
      name: 'Bridged USD Coin',
      symbol: 'USDC.e',
      decimals: 6,
      chainId: 146,
      logoURI:
        'https://assets.smold.app/api/token/146/0x29219dd400f2Bf60E5a23d13Be72B486D4038894/logo-128.png',
    },
    {
      address: '0x6047828dc181963ba44974801FF68e538dA5eaF9',
      name: 'Tether USD',
      symbol: 'USDT',
      decimals: 6,
      chainId: 146,
      logoURI:
        'https://assets.smold.app/api/token/146/0x6047828dc181963ba44974801FF68e538dA5eaF9/logo-128.png',
    },
    {
      address: '0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38',
      name: 'Wrapped Sonic',
      symbol: 'wSonic',
      decimals: 18,
      chainId: 146,
      logoURI:
        'https://assets.smold.app/api/token/146/0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38/logo-128.png',
    },
  ],
  999: [
    {
      address: '0x72c527d3efDe2169AA950EFc9573C838cf125D21',
      name: 'Summer',
      symbol: 'SUMMER',
      decimals: 18,
      chainId: 999,
      logoURI:
        'https://assets.smold.app/api/token/8453/0x194f360D130F2393a5E9F3117A6a1B78aBEa1624/logo-128.png',
    },
    {
      address: '0xb88339cb7199b77e23db6e890353e22632ba630f',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      chainId: 999,
      logoURI:
        'https://assets.smold.app/api/token/999/0xb88339cb7199b77e23db6e890353e22632ba630f/logo-128.png',
    },
    {
      address: '0x5555555555555555555555555555555555555555',
      name: 'Wrapped HYPE',
      symbol: 'wHYPE',
      decimals: 18,
      chainId: 999,
      logoURI:
        'https://assets.smold.app/api/token/999/0x5555555555555555555555555555555555555555/logo-128.png',
    },
  ],
}
