import { AaveV3ArkContracts } from '../../ignition/modules/arks/aavev3-ark'
import { CompoundV3ArkContracts } from '../../ignition/modules/arks/compoundv3-ark'
import { ERC4626ArkContracts } from '../../ignition/modules/arks/erc4626-ark'
import { MorphoArkContracts } from '../../ignition/modules/arks/morpho-ark'
import { MorphoVaultArkContracts } from '../../ignition/modules/arks/morpho-vault-ark'
import { PendleLPArkContracts } from '../../ignition/modules/arks/pendle-lp-ark'
import { PendlePTArkContracts } from '../../ignition/modules/arks/pendle-pt-ark'
import { BuyAndBurnContracts } from '../../ignition/modules/buy-and-burn'
import { CoreContracts } from '../../ignition/modules/core'
import { FleetContracts } from '../../ignition/modules/fleet'
import { GovContracts } from '../../ignition/modules/gov'
import { ArkContracts } from '../deploy-ark'

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
      'Tip Jar                   ': contracts.tipJar,
      'Raft                      ': contracts.raft,
      'Configuration Manager     ': contracts.configurationManager,
      'Harbor Commander          ': contracts.harborCommand,
      'Admiral Quarters          ': contracts.admiralsQuarters,
    })
    logger.logAddresses()
  }
  static logGov(contracts: GovContracts): void {
    const logger = new ModuleLogger('GovModule', {
      'Access Manager': contracts.protocolAccessManager,
      'Rewards Redeemer': contracts.rewardsRedeemer,
      'Summer Governor': contracts.summerGovernor,
      'Timelock Controller': contracts.timelock,
      'Summer Token': contracts.summerToken,
    })
    logger.logAddresses()
  }
  static logBuyAndBurn(contracts: BuyAndBurnContracts): void {
    const logger = new ModuleLogger('BuyAndBurnModule', {
      'Buy and Burn': contracts.buyAndBurn,
    })
    logger.logAddresses()
  }
  static logAaveV3Ark(contracts: AaveV3ArkContracts): void {
    const logger = new ModuleLogger('AaveV3ArkModule', {
      'Aave V3 Ark': contracts.aaveV3Ark,
    })
    logger.logAddresses()
  }

  static logCompoundV3Ark(contracts: CompoundV3ArkContracts): void {
    const logger = new ModuleLogger('CompoundV3ArkModule', {
      'Compound V3 Ark': contracts.compoundV3Ark,
    })
    logger.logAddresses()
  }
  static logArk(contracts: ArkContracts): void {
    const logger = new ModuleLogger('ArkModule', {
      Ark: contracts.ark,
    })
    logger.logAddresses()
  }
  static logFleet(contracts: FleetContracts): void {
    const logger = new ModuleLogger('FleetModule', {
      'Fleet Commander': contracts.fleetCommander,
    })
    logger.logAddresses()
  }

  static logMorphoArk(contracts: MorphoArkContracts): void {
    const logger = new ModuleLogger('MorphoArkModule', {
      'Morpho Ark': contracts.morphoArk,
    })
    logger.logAddresses()
  }

  static logMorphoVaultArk(contracts: MorphoVaultArkContracts): void {
    const logger = new ModuleLogger('MorphoVaultArkModule', {
      'Morpho Vault Ark': contracts.morphoVaultArk,
    })
    logger.logAddresses()
  }

  static logERC4626Ark(contracts: ERC4626ArkContracts): void {
    const logger = new ModuleLogger('ERC4626ArkModule', {
      'ERC4626 Ark': contracts.erc4626Ark,
    })
    logger.logAddresses()
  }

  static logPendlePTArk(contracts: PendlePTArkContracts): void {
    const logger = new ModuleLogger('PendlePTArkModule', {
      'Pendle PT Ark': contracts.pendlePTArk,
    })
    logger.logAddresses()
  }

  static logPendleLPArk(contracts: PendleLPArkContracts): void {
    const logger = new ModuleLogger('PendleLPArkModule', {
      'Pendle LP Ark': contracts.pendleLPArk,
    })
    logger.logAddresses()
  }
}
