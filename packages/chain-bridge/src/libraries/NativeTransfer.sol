// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title NativeTransfer
 * @notice Shared helpers for sending native ETH with a controlled gas stipend.
 * @dev Modern Solidity guidance discourages using {address}.transfer because it hardcodes a 2300 gas stipend.
 *      Recipient contracts that rely on proxies, access control checks, or simply emit events frequently require
 *      more than 2300 gas, which would cause {transfer} to revert and could strand funds. Instead we forward
 *      native value via `.call{gas: Constants.NATIVE_SEND_GAS_STIPEND}`. The configurable stipend allows us to
 *      retain explicit control over gas forwarding while staying resilient to changes in the EVM gas schedule.
 */
library NativeTransfer {
    /**
     * @notice Sends native ETH to `recipient` using a bounded gas stipend.
     * @dev Returns whether the low-level call succeeded so the caller can decide how to handle failures (e.g. emit an
     *      event, retry, or revert). Passing `amount == 0` is treated as a no-op and returns true without performing a call.
     * @param recipient The destination address that should receive the native value.
     * @param amount The amount of native ETH to transfer.
     * @return success True if the transfer succeeded, false otherwise.
     */
    function sendNativeValue(
        address payable recipient,
        uint256 amount
    ) internal returns (bool success) {
        if (amount == 0) {
            return true;
        }

        (success, ) = recipient.call{
            value: amount,
            gas: Constants.NATIVE_SEND_GAS_STIPEND
        }("");
    }
}
