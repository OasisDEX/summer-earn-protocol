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

export interface TenderlyRawBundleResponse {
  simulation_results?: TenderlySimResult[]
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
  salt?: string
  value?: string
}
// Formatted result for UI rendering
export interface SimulationResult {
  chainId: string
  status: 'idle' | 'loading' | 'success' | 'fail' | 'error'
  gasUsed?: number
  simulationId?: string
  shareUrl?: string
  error?: string
  balance?: string
}
