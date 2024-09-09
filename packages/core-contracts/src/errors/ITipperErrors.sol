// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface ITipperErrors {
    error InvalidFleetCommanderAddress();
    error InvalidTipJarAddress();
    error TipRateCannotExceedOneHundredPercent();
}
