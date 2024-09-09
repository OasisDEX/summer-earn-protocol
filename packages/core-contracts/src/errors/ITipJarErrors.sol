// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
interface ITipJarErrors {
    error InvalidRecipientAddress();
    error TipStreamAlreadyExists(address recipient);
    error InvalidTipStreamAllocation(Percentage invalidAllocation);
    error TotalAllocationExceedsOneHundredPercent();
    error TipStreamDoesNotExist(address recipient);
    error TipStreamLocked(address recipient);
    error NoSharesToRedeem();
    error NoAssetsToDistribute();
    error InvalidTreasuryAddress();
    error InvalidFleetCommanderAddress();
}
