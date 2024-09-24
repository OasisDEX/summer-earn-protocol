import { Address, BigInt } from '@graphprotocol/graph-ts'
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

export const protocolConfig: Protocol[] = [
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
  new Protocol('Metamorpho', [
    new ERC4626Product(
      getOrCreateToken(addresses.USDC),
      Address.fromString('0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB'),
      BigInt.fromI32(18928285),
      'Metamorpho',
    ),
    new ERC4626Product(
      getOrCreateToken(addresses.DAI),
      Address.fromString('0x83f20f44975d03b1b09e64809b757c47f942beea'),
      BigInt.fromI32(16428133),
      'Metamorpho',
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
      'WEETH',
      Address.fromString('0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee'),
    ),
    new GenericVaultProduct(
      getOrCreateToken(addresses.WETH),
      Address.fromString('0xf073bAC22DAb7FaF4a3Dd6c6189a70D54110525C'),
      BigInt.fromI32(18928285),
      'Genesis liquid restaking - gETH',
      Address.fromString('0xC29783738A475112Cafe58433Dd9D19F3a406619'),
    ),
    new GenericVaultProduct(
      getOrCreateToken(addresses.WETH),
      Address.fromString('0xbf5495Efe5DB9ce00f80364C8B423567e58d2110'),
      BigInt.fromI32(18928285),
      'renzo - ezETH',
      Address.fromString('0x387dBc0fB00b26fb085aa658527D5BE98302c84C'),
    ),
    new GenericVaultProduct(
      getOrCreateToken(addresses.WETH),
      Address.fromString('0xF1617882A71467534D14EEe865922de1395c9E89'),
      BigInt.fromI32(18928285),
      'Aspida - asETH',
      Address.fromString('0x1aCB59d7c5D23C0310451bcd7bA5AE46d18c108C'),
    ),
    new GenericVaultProduct(
      getOrCreateToken(addresses.WETH),
      Address.fromString('0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0'),
      BigInt.fromI32(18928285),
      'Swell - SWETH',
      Address.fromString('0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0'),
    ),
  ]),
  new Protocol('Staked Stables', [
    new GenericVaultProduct(
      getOrCreateToken(addresses.USDC),
      Address.fromString('0x80ac24aa929eaf5013f6436cda2a7ba190f5cc0b'),
      BigInt.fromI32(18928285),
      'Syrup - USDC',
      Address.fromString('0xd2c59781f1db84080a0592ce83fe265642a4a8eb'),
    ),
    new GenericVaultProduct(
      getOrCreateToken(addresses.SUSDE),
      Address.fromString('0x9D39A5DE30e57443BfF2A8307A4256c8797A3497'),
      BigInt.fromI32(18928285),
      'Ethena - SUSDE',
      Address.fromString('0x3A244e6B3cfed21593a5E5B347B593C0B48C7dA1'),
    ),
  ]),
]
