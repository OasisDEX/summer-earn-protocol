import { Address, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { addresses } from '../constants/addresses'
import { Protocol } from '../models/Protocol'
import { AaveV3Product } from '../products/AaveV3Product'
import { AeraProduct } from '../products/AeraProduct'
import { CompoundProduct } from '../products/CompoundProduct'
import { HyperlendProduct } from '../products/HyperlendProduct'
import { HypurrProduct } from '../products/HypurrProduct'
import { ERC4626FluidLiteProduct } from '../products/ERC4626FluidLiteProduct'
import { ERC4626ManualAssetsProduct } from '../products/ERC4626ManualAssetsProduct'
import { ERC4626Product } from '../products/ERC4626Product'
import { GearboxProduct } from '../products/GearboxProduct'
import { GenericVaultProduct } from '../products/GenericVault'
import { MoonwellProduct } from '../products/Moonwell'
import { OriginEthProduct } from '../products/OriginEthProduct'
import { PendleLpProduct } from '../products/PendleLp'
import { PendlePtProduct } from '../products/PendlePt'
import { SiloProduct } from '../products/Silo'
import { SkyRewardsProduct } from '../products/SkyRewardsProduct'
import { SkySUSDSProduct } from '../products/SkySUSDSProduct'
import { SparkProduct } from '../products/SparkProduct'
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
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc155444481854c60e7a29f4150373f479988f32d'),
          BigInt.fromI32(23144527),
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
        new GearboxProduct(
          getOrCreateToken(addresses.WSTETH),
          Address.fromString('0xFF94993fA7EA27Efc943645F95Adb36C1b81244b'),
          BigInt.fromI32(18798139),
          'Gearbox',
        ),
        new GearboxProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x9396dcbf78fc526bb003665337c5e73b699571ef'),
          BigInt.fromI32(24031082),
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
        new SparkProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
          BigInt.fromI32(18798139),
          'Spark',
        ),
        new SparkProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xC13e21B648A5Ee794902342038FF3aDAB66BE987'),
          BigInt.fromI32(18798140),
          'Spark',
        ),
        new SparkProduct(
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
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc582F04d8a82795aa2Ff9c8bb4c1c889fe7b754e'),
          BigInt.fromI32(22477748),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x0F359FD18BDa75e9c49bC027E7da59a4b01BF32a'),
          BigInt.fromI32(22477748),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xd63070114470f685b75B74D60EEc7c1113d33a3D'),
          BigInt.fromI32(22477748),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x777791C4d6DC2CE140D00D2828a7C93503c67777'),
          BigInt.fromI32(22822692),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x5b56F90340dBAa6a8693DADb141D620f0e154fE6'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xA8875aaeBc4f830524e35d57F9772FfAcbdD6C45'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xd41830d88dfD08678b0B886E0122193d54b02Acc'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x4F460bb11cf958606C69A963B4A17f9DaEEea8b6'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x98dC52125E9D0Eb8D62892334e502B555D04a787'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEeF1f5Bd88285E5B239B6AAcb991d38ccA23Ac9'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x1E2aAaDcF528b9cC08F43d4fd7db488cE89F5741'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x62fE596d59fB077c2Df736dF212E0AFfb522dC78'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x0562AE950276B24F3eAE0d0a518dADB7Ad2F8D66'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEefb9f61CC44895d8AEc381373555a64191A9c4'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd'),
          BigInt.fromI32(24031082),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xb0f05E4De970A1aaf77f8C2F823953a367504BA9'),
          BigInt.fromI32(24500124),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x9B5E92fd227876b4C07a8c02367E2CB23c639DfA'),
          BigInt.fromI32(24500124),
          'Morpho',
        ),
        // Morpho_V2 vaults
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x8c106EEDAd96553e64287A5A6839c3Cc78afA3D0'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xe2221Aa07ec3266DA87763E2b1e28d07A8a4e53b'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xeBBaE8CfAbB0092d5B32f00EBeE0c8139d24dDcd'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xB885F6d448dA7E2C642Ec31190B629E40E87B069'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x0229dB3921dE71CFa43Cfe9fb6A87b403647A9ae'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x69A238Ae7ebeb3c53ff3B544E48B96a2142fc284'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xD1E9242e075Db4bdd3f3c721D7d5fd4180A94A7e'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x951a9f4A2cE19B9DeA6B37e691d076A345b6c0F8'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEeFF047C03714965a54b671A37C18beF6b96210'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x093272C07700d3cA5301C3Bf9B3A392624179E2F'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x9a1D6bd5b8642C41F25e0958129B85f8E1176F3e'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xD5cCe260E7a755DDf0Fb9cdF06443d593AaeaA13'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEEf3f3A04e28895f3D5163d910474901981183D'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xbeeff2C5bF38f90e3482a8b19F12E5a6D2FCa757'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xbeef088055857739C12CD3765F20b7679Def0f51'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x7ceB0f01Cb7187a2EBED5661eCC4d5701d8F2350'),
          BigInt.fromI32(24500124),
          'Morpho_V2',
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
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xbeef003C68896c7D2c3c60d363e8d71a49Ab2bf9'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0xbeeff07d991C04CD640DE9F15C08ba59c4FEDEb7'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
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
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x9a8bC3B04b7f3D87cfC09ba407dCED575f2d61D8'),
          BigInt.fromI32(22287363),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xbEEF36A5C1372F8D7d211527FCE9f83FE02d8A73'),
          BigInt.fromI32(22480094),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x739d8a60ED4b14E4cB6DCAEAF79d2ec0Ca092237'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x701907283a57FF77E255C3f1aAD790466B8CE4ef'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x0bB2751a90fFF62e844b1521637DeD28F3f5046A'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x47fe8Ab9eE47DD65c24df52324181790b9F47EfC'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xE89371eAaAC6D46d4C3ED23453241987916224FC'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xf79F51f8F473eD34f6b2b13ee74c3208286D53EB'),
          BigInt.fromI32(23350000),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8'),
          BigInt.fromI32(24031082),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xbeef0046fcab1dE47E41fB75BB3dC4Dfc94108E3'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xBb50A5341368751024ddf33385BA8cf61fE65FF9'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
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
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xbe518068EB6135117207256F8C9aFf81B4382DB1'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x43fCd85E8D9D003D515f886891B7C742AC9f92da'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x5dbf760b4fd0cDdDe0366b33aEb338b2A6d77725'),
          BigInt.fromI32(24375455),
          'Morpho_V2',
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
        new SkyRewardsProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x0650CAF159C5A49f711e8169D4336ECB9b950275'),
          BigInt.fromI32(22373484),
          'Sky',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE'),
          BigInt.fromI32(22477748),
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
        new ERC4626FluidLiteProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xa0d3707c569ff8c87fa923d3823ec5d81c98be78'),
          BigInt.fromI32(22373484),
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
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xf2f826c190D020A6D1EC422bF2269E63b8b315E0'),
          BigInt.fromI32(22477748),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xcBC9B61177444A793B85442D3a953B90f6170b7D'),
          BigInt.fromI32(22477748),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x3573A84Bee11D49A1CbCe2b291538dE7a7dD81c6'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x98281466aBcF48eAAD8c6E22dEdD18A3426A93b4'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xc727069c0eb261Be642272fe3848518192683fFc'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x3C75C170671acb394804DfAf63e4F9891C121625'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x481D4909D7ca2eb27c4975f08dCE07DBeF0d3Fa7'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xa94F9CE821C7bD57cc12991CB46ca19f5789278F'),
          BigInt.fromI32(23350000),
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
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x716bF454066a84F39A2F78b5707e79a9d64f1225'),
          BigInt.fromI32(22287363),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x87c414825aB3d1E9bdC773e9B1fD968822c9CF51'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x45c3B59d53e2e148Aaa6a857521059676D5c0489'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xc2c4aBae84fbb5b7bAAB52301A924b1F986C66bd'),
          BigInt.fromI32(23350000),
          'Euler',
        ),
      ]),
      new Protocol('Syrup', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b'),
          BigInt.fromI32(22373484),
          'Syrup',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D'),
          BigInt.fromI32(22373484),
          'Syrup',
        ),
      ]),
      new Protocol('Origin', [
        new OriginEthProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3'),
          BigInt.fromI32(22373484),
          'Origin',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x85B78AcA6Deae198fBF201c82DAF6Ca21942acc6'),
          BigInt.fromI32(23471001),
          'Origin',
        ),
      ]),
      new Protocol('Term', [
        new ERC4626ManualAssetsProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xA9ca4909700505585B1aD2a1579dA3b670FFA9c4'),
          BigInt.fromI32(22480094),
          'Term',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x6e7d87a64c78593781452a014dc989100B24a4aF'),
          BigInt.fromI32(22480094),
          'Term',
        ),
      ]),
      new Protocol('Silo', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xed9278c5188f37670b33ef3B00729E38260cd5D5'),
          BigInt.fromI32(22822692),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x8399C8Fc273bD165C346Af74A02e65f10e4FD78F'),
          BigInt.fromI32(23388531),
          'Silo',
        ),
      ]),
      new Protocol('InfiniFi', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xDBDC1Ef57537E34680B898E1FEBD3D68c7389bCB'),
          BigInt.fromI32(23631727),
          'InfiniFi',
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
      new Protocol('Sky', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x940098b108fB7D0a7E374f6eDED7760787464609'),
          BigInt.fromI32(311940473),
          'Sky',
        ),
      ]),
      new Protocol('Silo', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x2BA39e5388aC6C702Cb29AEA78d52aa66832f1ee'),
          BigInt.fromI32(22822692),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x83b90F83afdFE24DDc4e300c8EB1C5b2c7544C81'),
          BigInt.fromI32(368171538),
          'Silo',
        ),
        new SiloProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x2433D6AC11193b4695D9ca73530de93c538aD18a'),
          BigInt.fromI32(368171538),
          'Silo',
        ),
      ]),
      new Protocol('Morpho', [
        // USDC
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x7c574174DA4b2be3f705c6244B4BfA0815a8B3Ed'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x7e97fa6893871A2751B5fE961978DCCb2c201E65'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x87DEAE530841A9671326C9D5B9f91bdB11F3162c'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x250CF7c82bAc7cB6cf899b6052979d4B5BA1f9ca'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xa60643c90A542A95026C0F1dbdB0615fF42019Cf'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        // USDT
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x139250CdB310D657eAC506c7C7FC6AcDE34Af1ec'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x6d57dAd0F1c4da0C1d5443AE8F7f8a50BDb9Cf75'),
          BigInt.fromI32(368171538),
          'Morpho',
        ),
      ]),
      new Protocol('Euler', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x0a1eCC5Fe8C9be3C809844fcBe615B46A869b899'),
          BigInt.fromI32(368171538),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDT),
          Address.fromString('0x37512F45B4ba8808910632323b73783Ca938CD51'),
          BigInt.fromI32(368171538),
          'Euler',
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
        new CompoundProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x46e6b214b524310239732D51387075E0e70970bf'),
          BigInt.fromI32(29043399),
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
        new AaveV3Product(
          getOrCreateToken(addresses.EURC),
          Address.fromString('0xA238Dd80C259a72e81d7e4664a9801593F98d1c5'),
          BigInt.fromI32(7551731),
          'AaveV3',
        ),
        new AaveV3Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xA238Dd80C259a72e81d7e4664a9801593F98d1c5'),
          BigInt.fromI32(29043399),
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
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x9272D6153133175175Bc276512B2336BE3931CE9'),
          BigInt.fromI32(29043399),
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
          Address.fromString('0x616a4E1db48e22028f6bbf20444Cd3b8e3273738'),
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
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x23479229e52Ab6aaD312D0B03DF9F33B46753B5e'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xB7890CEE6CF4792cdCC13489D36D9d42726ab863'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xE74c499fA461AF1844fCa84204490877787cED56'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x1D3b1Cd0a0f242d598834b3F2d126dC6bd774657'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x236919F11ff9eA9550A4287696C2FC9e18E6e890'),
          BigInt.fromI32(34234416),
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
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1'),
          BigInt.fromI32(29043399),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xbEEf050a7485865A7a8d8Ca0CC5f7536b7a3443e'),
          BigInt.fromI32(29043399),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x6b13c060F13Af1fdB319F52315BbbF3fb1D88844'),
          BigInt.fromI32(29043399),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x27d8c7273fd3fcc6956a0b370ce5fd4a7fc65c18'),
          BigInt.fromI32(32281914),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x5A32099837D89E3a794a44fb131CBbAD41f87a8C'),
          BigInt.fromI32(34234416),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x1D795E29044A62Da42D927c4b179269139A28A6B'),
          BigInt.fromI32(34234416),
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
        new MoonwellProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22'),
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
      new Protocol('Origin', [
        new OriginEthProduct(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3'),
          BigInt.fromI32(29506052),
          'Origin',
        ),
      ]),
      new Protocol('Aera', [
        new AeraProduct(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x000000000001cdb57e58fa75fe420a0f4d6640d5'),
          BigInt.fromI32(33307996),
          'Aera',
        ),
      ]),
      new Protocol('Euler', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x085178078796Da17B191f9081b5E2fCCc79A7eE7'),
          BigInt.fromI32(34234416),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0x859160DB5841E5cfB8D3f144C6b3381A85A4b410'),
          BigInt.fromI32(29043399),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.WETH),
          Address.fromString('0xF3BB6b0a9bEAF9240D7F4a91341d5Df6bF37cAea'),
          BigInt.fromI32(34234416),
          'Euler',
        ),
      ]),
      new Protocol('Extrafi', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0x589A7339C6d0c8777E7429F57f2f95c069c37288'),
          BigInt.fromI32(37783000),
          'Extrafi',
        ),
      ]),
      new Protocol('40acres', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDC),
          Address.fromString('0xB99B6dF96d4d5448cC0a5B3e0ef7896df9507Cf5'),
          BigInt.fromI32(41101798),
          '40acres',
        ),
      ]),
    ]
  }
  private initSonic(): Protocol[] {
    return [
      new Protocol('Euler', [
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x196F3C7443E940911EE2Bb88e019Fd71400349D9'),
          BigInt.fromI32(12744800),
          'Euler',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x3D9e5462A940684073EED7e4a13d19AE0Dcd13bc'),
          BigInt.fromI32(12744800),
          'Euler',
        ),
      ]),
      new Protocol('AaveV3', [
        new AaveV3Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3'),
          BigInt.fromI32(12744800),
          'AaveV3',
        ),
      ]),
      new Protocol('Silo', [
        new SiloProduct(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x4E216C15697C1392fE59e1014B009505E05810Df'),
          BigInt.fromI32(12744800),
          'Silo',
        ),
        new SiloProduct(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0x322e1d5384aa4ED66AeCa770B95686271de61dc3'),
          BigInt.fromI32(12744800),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xF6F87073cF8929C206A77b0694619DC776F89885'),
          BigInt.fromI32(27007101),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xF75AE954D30217B4EE70DbFB33f04162aa3Cf260'),
          BigInt.fromI32(27007101),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xcca902f2d3d265151f123d8ce8FdAc38ba9745ed'),
          BigInt.fromI32(27007101),
          'Silo',
        ),
        new ERC4626Product(
          getOrCreateToken(addresses.USDCE),
          Address.fromString('0xf6bC16B79c469b94Cdd25F3e2334DD4FEE47A581'),
          BigInt.fromI32(36683119),
          'Silo',
        ),
      ]),
    ]
  }
  private initHyperLiquid(): Protocol[] {
    return [
      new Protocol('Morpho', [
        // USDC vaults
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb88339cb7199b77e23db6e890353e22632ba630f')),
          Address.fromString('0x8a862fd6c12f9ad34c9c2ff45ab2b6712e8cea27'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb88339cb7199b77e23db6e890353e22632ba630f')),
          Address.fromString('0x08C00F8279dFF5B0CB5a04d349E7d79708Ceadf3'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        // USDT vaults
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0x9896a8605763106e57A51aa0a97Fe8099E806bb3'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0xfc5126377f0efc0041c0969ef9ba903ce67d151e'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0x53A333e51E96FE288bC9aDd7cdC4B1EAD2CD2FfA'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0xe5ADd96840F0B908ddeB3Bd144C0283Ac5ca7cA0'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0x3Bcc0a5a66bB5BdCEEf5dd8a659a4eC75F3834d8'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
        new ERC4626Product(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0x51F64488d03D8B210294dA2BF70D5db0Bc621B0c'),
          BigInt.fromI32(23831958),
          'Morpho',
        ),
      ]),
      new Protocol('Hyperlend', [
        new HyperlendProduct(
          getOrCreateToken(Address.fromString('0xb88339cb7199b77e23db6e890353e22632ba630f')),
          Address.fromString('0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b'),
          BigInt.fromI32(23831958),
          'Hyperlend',
        ),
        new HyperlendProduct(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b'),
          BigInt.fromI32(23831958),
          'Hyperlend',
        ),
      ]),
      new Protocol('Hypurr', [
        new HypurrProduct(
          getOrCreateToken(Address.fromString('0xb88339cb7199b77e23db6e890353e22632ba630f')),
          Address.fromString('0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b'),
          BigInt.fromI32(23831958),
          'Hypurr',
        ),
        new HypurrProduct(
          getOrCreateToken(Address.fromString('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb')),
          Address.fromString('0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b'),
          BigInt.fromI32(23831958),
          'Hypurr',
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
      } else if (network == 'sonic-mainnet') {
        this.configs.set(network, this.initSonic())
      } else if (network == 'hyperliquid' || network == 'hyperevm') {
        this.configs.set(network, this.initHyperLiquid())
      } else {
        this.configs.set(network, [])
      }
    }
    return this.configs.get(network)
  }
}

export const protocolConfig: Protocol[] = new ProtocolConfig().getConfig()
