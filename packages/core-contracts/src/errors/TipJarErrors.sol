// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Percentage} from "../types/Percentage.sol";

error InvalidRecipientAddress();
error TipStreamAlreadyExists(address recipient);
error InvalidTipStreamAllocation(Percentage invalidAllocation);
error TotalAllocationExceedsOneHundredPercent();
error TipStreamDoesNotExist(address recipient);
error TipStreamMinTermNotReached(address recipient);
error NoAssetsToDistribute();
error InvalidTreasuryAddress();
error InvalidFleetCommanderAddress();
