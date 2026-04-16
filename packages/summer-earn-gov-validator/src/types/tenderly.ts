export interface TenderlySimResult {
  transaction: {
    hash: string
    status: boolean
    gas_used: number
    error_message?: string
  }
  simulation: {
    id: string
    status: boolean
    gas_used: number
    error_message?: string
  }
}

export interface TenderlyChainResult {
  simulation_results?: TenderlySimResult[]
  shareUrl?: string
  shareUrls?: string[]
  error?: string
  balance?: string
}

export interface SimulateApiResponse {
  results: Record<string, TenderlyChainResult>
}

// Internal Action type for the simulation API
export interface Action {
  chainId: string
  target: string
  method: string
  calldata: string
}
