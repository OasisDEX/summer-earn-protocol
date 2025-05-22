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
