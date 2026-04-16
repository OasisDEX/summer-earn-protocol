import { Address } from 'viem'

export interface DeploymentContract {
  address: Address
  [key: string]: unknown
}

export interface DeploymentConfig {
  [chainKey: string]: {
    deployedContracts?: {
      govV2?: {
        timelock?: {
          address: string
        }
      }
      [key: string]: DeploymentContract | Record<string, DeploymentContract | unknown> | unknown
    }
  }
}
