// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IFleetDepositAdapter} from "../../src/interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

/**
 * @title MockFleetDepositAdapterNoSupport
 * @notice Mock adapter that doesn't support fleet deposits for testing
 */
contract MockFleetDepositAdapterNoSupport is IFleetDepositAdapter {
    function executeCrossChainFleetDeposit(
        uint16,
        address,
        uint256,
        address,
        bytes memory,
        BridgeTypes.AdapterParams calldata
    ) external payable override returns (bytes32) {
        revert("Fleet deposits not supported");
    }

    function supportsFleetDeposits() external pure override returns (bool) {
        return false; // Does not support fleet deposits
    }
}
