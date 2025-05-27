import { Address } from 'viem'

export interface ArkParams {
  name: string
  details: string
  accessManager: Address
  configurationManager: Address
  asset: Address
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  requiresKeeperData: boolean
  maxDepositPercentageOfTVL: string
}
