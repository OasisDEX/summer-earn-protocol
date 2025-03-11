export interface Token {
  id: string;
  name: string;
  symbol: string;
  decimals: number;
  lastPriceUSD?: string;
  lastPriceBlockNumber?: string;
}

export interface Ark {
  id: string;
  address: string;
  commander: string;
}

export interface Auction {
  id: string;
  auctionId: string;
  ark: Ark;
  rewardToken: Token;
  buyToken: Token;
  startBlock: string;
  endBlock?: string;
  startTimestamp: string;
  endTimestamp: string;
  startPrice: string;
  endPrice: string;
  tokensLeft: string;
  tokensLeftNormalized: string;
  kickerRewardPercentage: string;
  decayType?: string;
  duration: string;
  isFinalized: boolean;
}

export interface TokensPurchased {
  id: string;
  auction: Auction;
  buyer: {
    id: string;
    address: string;
  };
  tokensPurchased: string;
  tokensPurchasedNormalized: string;
  pricePerToken: string;
  pricePerTokenNormalized: string;
  totalCost: string;
  totalCostNormalized: string;
  timestamp: string;
  marketPriceInUSDNormalized: string;
}

export interface ChainConfig {
  name: string;
  id: number;
  chain: any;
  subgraphEndpoint: string;
  raftAddress: string;
  rpcUrl: string;
} 