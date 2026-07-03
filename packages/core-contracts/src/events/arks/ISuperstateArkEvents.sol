// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title ISuperstateArkEvents
 * @notice Events emitted by Superstate Ark contracts
 */
interface ISuperstateArkEvents {
    /**
     * @notice Emitted when a subscription (deposit) to Superstate is executed
     * @param usdcAmount The amount of USDC subscribed
     * @param target The address that the subscription was directed to
     */
    event SubscriptionExecuted(uint256 usdcAmount, address target);
    /**
     * @notice Emitted when a redemption from Superstate is executed
     * @param shareAmount The amount of shares redeemed
     * @param expectedUsdc The expected USDC amount to be received from the redemption
     */
    event RedemptionExecuted(uint256 shareAmount, uint256 expectedUsdc);
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );
}
