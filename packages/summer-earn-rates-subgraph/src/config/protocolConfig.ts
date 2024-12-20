import { Address, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { addresses } from '../constants/addresses'
import { Protocol } from '../models/Protocol'
import { AaveV3Product } from '../products/AaveV3Product'
import { CompoundProduct } from '../products/CompoundProduct'
import { ERC4626Product } from '../products/ERC4626Product'
import { GearboxProduct } from '../products/GearboxProduct'
import { GenericVaultProduct } from '../products/GenericVault'
import { PendleLpProduct } from '../products/PendleLp'
import { PendlePtProduct } from '../products/PendlePt'
import { getOrCreateToken } from '../utils/initializers'

/**
 * ProtocolConfig class
 *
 * This class manages the configuration of protocols and products for different networks.
 *
 * To add a new network:
 * 1. Create a new private method (e.g., initNewNetwork) following the pattern of existing ones.
 * 2. Implement the network-specific configuration in this method.
 * 3. Call this new method in the constructor.
 *
 * To add a new protocol or product to an existing network:
 * 1. Find the appropriate init method for the network (e.g., initMainnet, initArbitrum, etc.)
 * 2. Add the new protocol or product within the existing array or create a new Protocol instance.
 *
 * Example of adding a new network:
 *
 * private initPolygon(): Protocol[] {
 *  return [
 *     new Protocol('AaveV3', [
 *       new AaveV3Product(
 *         getOrCreateToken(addresses.POLYGON_USDC),
 *         Address.fromString('POLYGON_AAVE_POOL_ADDRESS'),
 *         BigInt.fromI32(POLYGON_START_BLOCK),
 *         'AaveV3'
 *       ),
 *       // Add more Polygon-specific products...
 *     ]),
 *     // Add more Polygon-specific protocols...
 *   ])
 * }
 *
 * Then in the constructor:
 * this.initPolygon()
 *
 * Example of adding a new protocol to mainnet:
 *
 * In the initMainnet method:
 * new Protocol('NewProtocol', [
 *   new NewProduct(
 *     getOrCreateToken(addresses.NEW_TOKEN),
 *     Address.fromString('NEW_POOL_ADDRESS'),
 *     BigInt.fromI32(START_BLOCK),
 *     'NewProtocol'
 *   ),
 *   // Add more products for this protocol...
 * ]),
 */
class ProtocolConfig {
  private configs: Map<string, Protocol[]>

  constructor() {
    this.configs = new Map<string, Protocol[]>()
  }

  private initMainnet(): Protocol[] {
    return [
      new Protocol('CompoundV3', [
        new CompoundProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc3d688B66703497DAA19211EEdff47f25384cdc3'),
          BigInt.fromI32(15331586),
          'CompoundV3',
        ),
        new CompoundProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xA17581A9E3356d9A858b789D68B4d866e593aE94'),
          BigInt.fromI32(16400710),
          'CompoundV3',
        ),
        new CompoundProduct(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840'),
          BigInt.fromI32(20190637),
          'CompoundV3',
        ),
        new CompoundProduct(
          getOrCreateToken(addresses.WSTETH),
          Address.fromString('0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3'),
          BigInt.fromI32(20683535),
          'CompoundV3',
        ),
      ]),
      new Protocol('Gearbox', [
        new GearboxProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xda00000035fef4082f78def6a8903bee419fbf8e'),
          BigInt.fromI32(18798139),
          'Gearbox',
        ),
        new GearboxProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xda0002859B2d05F66a753d8241fCDE8623f26F4f'),
          BigInt.fromI32(18798140),
          'Gearbox',
        ),
      ]),
      new Protocol('AaveV3', [
        new AaveV3Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2'),
          BigInt.fromI32(18798139),
          'AaveV3',
        ),
        new AaveV3Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2'),
          BigInt.fromI32(18798140),
          'AaveV3',
        ),
      ]),
      new Protocol('MorphoVault', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB'),
          BigInt.fromI32(18928285),
          'MorphoVault',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.DAI),
          Address.fromString('0x83f20f44975d03b1b09e64809b757c47f942beea'),
          BigInt.fromI32(16428133),
          'MorphoVault',
        ),
      ]),
      new Protocol('Pendle', [
        new PendlePtProduct(
          getOrCreateToken(addresses.SUSDE),
          Address.fromString('0xd1d7d99764f8a52aff007b7831cc02748b2013b5'),
          BigInt.fromI32(19909022),
          'PendlePt',
        ),
        new PendleLpProduct(
          getOrCreateToken(addresses.SUSDE),
          Address.fromString('0xd1d7d99764f8a52aff007b7831cc02748b2013b5'),
          BigInt.fromI32(19909022),
          'PendleLp',
        ),
      ]),
      // https://github.com/balancer/code-review/blob/main/rate-providers/rswethRateProvider.md
      new Protocol('LRT', [
        new GenericVaultProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee'),
          BigInt.fromI32(18928285),
          'weETH',
          Address.fromString('0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee'),
        ),
        new GenericVaultProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xf073bAC22DAb7FaF4a3Dd6c6189a70D54110525C'),
          BigInt.fromI32(18928285),
          'gETH',
          Address.fromString('0xC29783738A475112Cafe58433Dd9D19F3a406619'),
        ),
        new GenericVaultProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xbf5495Efe5DB9ce00f80364C8B423567e58d2110'),
          BigInt.fromI32(18928285),
          'ezETH',
          Address.fromString('0x387dBc0fB00b26fb085aa658527D5BE98302c84C'),
        ),
        new GenericVaultProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xF1617882A71467534D14EEe865922de1395c9E89'),
          BigInt.fromI32(18928285),
          'asETH',
          Address.fromString('0x1aCB59d7c5D23C0310451bcd7bA5AE46d18c108C'),
        ),
        new GenericVaultProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0'),
          BigInt.fromI32(18928285),
          'swETH',
          Address.fromString('0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0'),
        ),
      ]),
      new Protocol('Staked Stables', [
        new GenericVaultProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b'),
          BigInt.fromI32(18928285),
          'sUSDC',
          Address.fromString('0xd2c59781f1db84080a0592ce83fe265642a4a8eb'),
        ),
        new GenericVaultProduct(
          getOrCreateToken(addresses.SUSDE),
          Address.fromString('0x9D39A5DE30e57443BfF2A8307A4256c8797A3497'),
          BigInt.fromI32(18928285),
          'SUSDE',
          Address.fromString('0x3A244e6B3cfed21593a5E5B347B593C0B48C7dA1'),
        ),
      ]),
    ]
  }

  private initArbitrum(): Protocol[] {
    return [
      new Protocol('CompoundV3', [
        new CompoundProduct(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA'),
          BigInt.fromI32(159160679),
          'CompoundV3',
        ),
        new CompoundProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf'),
          BigInt.fromI32(159160679),
          'CompoundV3',
        ),
      ]),
      new Protocol('Gearbox', [
        new GearboxProduct(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xa76c604145D7394DEc36C49Af494C144Ff327861'),
          BigInt.fromI32(184650413),
          'Gearbox',
        ),
        new GearboxProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6'),
          BigInt.fromI32(221759351),
          'Gearbox',
        ),
      ]),
      new Protocol('AaveV3', [
        new AaveV3Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
          BigInt.fromI32(159160679),
          'AaveV3',
        ),
        new AaveV3Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
          BigInt.fromI32(159160679),
          'AaveV3',
        ),
      ]),
    ]
  }

  private initOptimism(): Protocol[] {
    return [
      new Protocol('CompoundV3', [
        new CompoundProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x794a61358d6845594f94dc1db02a252b5b4814ad'),
          BigInt.fromI32(263570533),
          'CompoundV3',
        ),
      ]),
    ]
  }

  private initBase(): Protocol[] {
    return [
      new Protocol('CompoundV3', [
        new CompoundProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xb125E6687d4313864e53df431d5425969c15Eb2F'),
          BigInt.fromI32(7551731),
          'CompoundV3',
        ),
      ]),
      new Protocol('AaveV3', [
        new AaveV3Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xA238Dd80C259a72e81d7e4664a9801593F98d1c5'),
          BigInt.fromI32(7551731),
          'AaveV3',
        ),
      ]),
      new Protocol('Fluid', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xf42f5795D9ac7e9D757dB633D693cD548Cfd9169'),
          BigInt.fromI32(17551731),
          'Fluid',
        ),
      ]),
      new Protocol('Morpho', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca'),
          BigInt.fromI32(15620450),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12'),
          BigInt.fromI32(15330380),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61'),
          BigInt.fromI32(15327791),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x12AFDeFb2237a5963e7BAb3e2D46ad0eee70406e'),
          BigInt.fromI32(15626272),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183'),
          BigInt.fromI32(15183452),
          'Morpho',
        ),
      ]),
    ]
  }

  public getConfig(): Protocol[] {
    const network = dataSource.network()
    if (!this.configs.has(network)) {
      if (network == 'mainnet') {
        this.configs.set(network, this.initMainnet())
      } else if (network == 'arbitrum-one') {
        this.configs.set(network, this.initArbitrum())
      } else if (network == 'optimism') {
        this.configs.set(network, this.initOptimism())
      } else if (network == 'base') {
        this.configs.set(network, this.initBase())
      } else {
        this.configs.set(network, [])
      }
    }
    return this.configs.get(network)
  }
}

export const protocolConfig: Protocol[] = new ProtocolConfig().getConfig()
