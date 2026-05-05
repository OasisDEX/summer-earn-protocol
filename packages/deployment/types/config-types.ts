import { Address } from 'viem'

import { CoreContracts as CoreContractsBase } from '../ignition/modules/core'
import type {
  ArkConfig,
  ArkConfigParams,
  BaseConfig,
  Config,
  CrossChainConfig,
  DeployedBridge,
  FleetConfig,
  FleetDeployment,
  FleetDetails,
  InstitutionFleetEntry,
  InstitutionNetwork,
  OperatorType,
} from '../scripts/helpers/zod-schemas'

export { ArkType, arkTypes, SupportedNetworks, Token } from './base-types'

export type {
  ArkConfig,
  ArkConfigParams,
  BaseConfig,
  Config,
  CrossChainConfig,
  DeployedBridge,
  FleetConfig,
  FleetDeployment,
  FleetDetails,
  InstitutionFleetEntry,
  InstitutionNetwork,
  OperatorType,
}

export interface CoreContracts extends CoreContractsBase {
  institutionalVaultRegistry?: { address: Address }
}
