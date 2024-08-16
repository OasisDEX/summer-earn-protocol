import { CoreContracts } from '../ignition/modules/core'
import { AaveV3ArkContracts } from '../ignition/modules/aavev3-ark'

export class ModuleLogger {
  private moduleName: string
  private contracts: Record<string, { address: string }>

  constructor(moduleName: string, contracts: Record<string, { address: string }>) {
    this.moduleName = moduleName
    this.contracts = contracts
  }

  logAddresses(): void {
    console.log(`\n${this.moduleName} Deployment Addresses:`)
    console.log('======================================')

    for (const [contractName, contract] of Object.entries(this.contracts)) {
      console.log(`${contractName}: ${contract.address}`)
    }

    console.log('======================================\n')
  }

  static logCore(contracts: CoreContracts): void {
    const logger = new ModuleLogger('CoreModule', {
      'Protocol Access Manager': contracts.protocolAccessManager,
      'Tip Jar': contracts.tipJar,
      Raft: contracts.raft,
      'Configuration Manager': contracts.configurationManager,
    })
    logger.logAddresses()
  }

  static logAaveV3Ark(contracts: AaveV3ArkContracts): void {
    const logger = new ModuleLogger('AaveV3ArkModule', {
      'Aave V3 Ark': contracts.aaveV3Ark,
    })
    logger.logAddresses()
  }
}
