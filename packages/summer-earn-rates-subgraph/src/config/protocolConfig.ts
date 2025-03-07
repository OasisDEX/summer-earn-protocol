import { Address, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { addresses } from '../constants/addresses'
import { Protocol } from '../models/Protocol'
import { AaveV3Product } from '../products/AaveV3Product'
import { CompoundProduct } from '../products/CompoundProduct'
import { ERC4626Product } from '../products/ERC4626Product'
import { GearboxProduct } from '../products/GearboxProduct'
import { GenericVaultProduct } from '../products/GenericVault'
import { MoonwellProduct } from '../products/Moonwell'
import { PendleLpProduct } from '../products/PendleLp'
import { PendlePtProduct } from '../products/PendlePt'
import { SkySUSDSProduct } from '../products/SkySUSDSProduct'
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
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x05a811275fe9b4de503b3311f51edf6a856d936e'),
          BigInt.fromI32(18798139),
          'Gearbox',
        ),
        new GearboxProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xda0002859b2d05f66a753d8241fcde8623f26f4f'),
          BigInt.fromI32(18798139),
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
        new AaveV3Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2'),
          BigInt.fromI32(18798140),
          'AaveV3',
        ),
      ]),
      new Protocol('Spark', [
        new AaveV3Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
          BigInt.fromI32(18798139),
          'Spark',
        ),
        new AaveV3Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
          BigInt.fromI32(18798140),
          'Spark',
        ),
        new AaveV3Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
          BigInt.fromI32(18798140),
          'Spark',
        ),
      ]),
      new Protocol('Morpho', [
        // USDC vaults
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x186514400e52270cef3D80e1c6F8d10A75d47344'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xdd0f28e19C1780eb6396170735D45153D261490d'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x60d715515d4411f7F43e4206dc5d4a3677f0eC78'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEeFFF209270748ddd194831b3fa287a5386f5bC'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),

        // USDT vaults
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x2C25f6C25770fFEC5959D34B94Bf898865e5D6b1'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xbEef047a543E45807105E51A8BBEFCc5950fcfBa'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x8CB3649114051cA5119141a34C200D65dc0Faa73'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x95EeF579155cd2C5510F312c8fA39208c3Be01a8'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xA0804346780b4c2e3bE118ac957D1DB82F9d7484'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        // WETH vaults
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x78Fc2c2eD1A4cDb5402365934aE5648aDAd094d0'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xBEEf050ecd6a16c4e7bfFbB52Ebba7846C4b8cD4'),
          BigInt.fromI32(18928285),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x2371e134e3455e0593363cbf89d3b6cf53740618'),
          BigInt.fromI32(18928285),
          'Morpho',
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
      new Protocol('Sky', [
        new SkySUSDSProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xa188eec8f81263234da3622a406892f3d630f98c'),
          BigInt.fromI32(18928285),
          'Sky',
        ),
      ]),
      new Protocol('Fluid', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33'),
          BigInt.fromI32(18798139),
          'Fluid',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x5C20B550819128074FD538Edf79791733ccEdd18'),
          BigInt.fromI32(18798139),
          'Fluid',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x90551c1795392094FE6D29B758EcCD233cFAa260'),
          BigInt.fromI32(18798139),
          'Fluid',
        ),
      ]),
      new Protocol('Euler', [
        // USDC vaults
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9'),
          BigInt.fromI32(18798139),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xe0a80d35bB6618CBA260120b279d357978c42BCE'),
          BigInt.fromI32(18798139),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xce45EF0414dE3516cAF1BCf937bF7F2Cf67873De'),
          BigInt.fromI32(18798139),
          'Euler',
        ),
        // USDT vaults
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x313603FA690301b0CaeEf8069c065862f9162162'),
          BigInt.fromI32(18798139),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x7c280DBDEf569e96c7919251bD2B0edF0734C5A8'),
          BigInt.fromI32(18798139),
          'Euler',
        ),
        // WETH vault
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2'),
          BigInt.fromI32(18798139),
          'Euler',
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
        new CompoundProduct(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07'),
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
        new AaveV3Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
          BigInt.fromI32(159160679),
          'AaveV3',
        ),
      ]),
      new Protocol('Fluid', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x4A03F37e7d3fC243e3f99341d36f4b829BEe5E03'),
          BigInt.fromI32(159160679),
          'Fluid',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x1A996cb54bb95462040408C06122D45D6Cdb6096'),
          BigInt.fromI32(312900000),
          'Fluid',
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
        new ERC4626Product(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0x1943FA26360f038230442525Cf1B9125b5DCB401'),
          BigInt.fromI32(27276276),
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
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A'),
          BigInt.fromI32(15183452),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0xf24608E0CCb972b0b0f4A6446a0BBf58c701a026'),
          BigInt.fromI32(27276276),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0xBeEF086b8807Dc5E5A1740C5E3a7C4c366eA6ab5'),
          BigInt.fromI32(27276276),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0x1c155be6bC51F2c37d472d4C2Eba7a637806e122'),
          BigInt.fromI32(27276276),
          'Morpho',
        ),
      ]),
      new Protocol('Moonwell', [
        new MoonwellProduct(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0xb682c840B5F4FC58B20769E691A6fa1305A501a2'),
          BigInt.fromI32(27276276),
          'Moonwell',
        ),
      ]),
      new Protocol('Sky', [
        new SkySUSDSProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x1601843c5E9bC251A3272907010AFa41Fa18347E'),
          BigInt.fromI32(15183452),
          'Sky',
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
