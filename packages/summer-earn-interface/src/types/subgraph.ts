export interface Product {
  id: string
  name: string
  protocol: string
  token: Token
  network: string
  pool: string
}

export interface Token {
  id: string
  address: string
  symbol: string
  decimals: string
  precision: string
}

export interface InterestRate {
  id: string
  type: string
  rate: string
  blockNumber: string
  timestamp: string
  protocol: string
  token: Token
  productId: string
  product: Product
}

export interface DailyInterestRate {
  id: string
  date: string
  sumRates: string
  updateCount: string
  averageRate: string
  protocol: string
  token: string
  productId: string
  product: Product
  interestRates: InterestRate[]
}

export interface HourlyInterestRate {
  id: string
  date: string
  sumRates: string
  updateCount: string
  averageRate: string
  protocol: string
  token: string
  productId: string
  product: Product
  interestRates: InterestRate[]
}

// Institutions subgraph types
export interface Institution {
  id: string
  configurationManager: string
  protocolAccessManager: string
  admiralsQuarters: string
  harborCommand: string
  active: boolean
  createdTimestamp: string
  createdBlockNumber: string
  vaults: {
    id: string
  }[]
}

export interface RoleEntity {
  id: string
  name: string
  owner: string
  targetContract: string
  accessController: string
  createdTimestamp: string
  createdBlockNumber: string
  institution: { id: string }
}

export interface VaultEntity {
  id: string
  name: string
  inputToken: { id: string }
  createdTimestamp: string
  createdBlockNumber: string
  institution: { id: string }
}
