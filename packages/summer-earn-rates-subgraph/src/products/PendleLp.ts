import { BigDecimal, BigInt, log } from '@graphprotocol/graph-ts'
import { BaseVaultProduct } from './BaseVaultProduct'
import { BigIntConstants, BigDecimalConstants } from '../constants/common'
import { PendleOracle } from '../../generated/EntryPoint/PendleOracle'
import { addresses } from '../constants/addresses'

export class PendleLpProduct extends BaseVaultProduct {
    getSharePrice(): BigDecimal {
        const pendleOracle = PendleOracle.bind(addresses.PENDLE_ORACLE);
        const maybeRate = pendleOracle.try_getLpToAssetRate(this.address, BigIntConstants.THIRTY_MINUTES_IN_SECONDS)
        if (!maybeRate.reverted) {
            return maybeRate.value.toBigDecimal();
        } else {
            return BigDecimalConstants.ZERO;
        }
    }
}