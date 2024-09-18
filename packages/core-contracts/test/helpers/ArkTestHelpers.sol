// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IArk} from "../../src/interfaces/IArk.sol";

import {Constants} from "../../src/contracts/libraries/Constants.sol";
import {Test, console} from "forge-std/Test.sol";

/// @title Ark Test Helpers
/// @notice Provides helper functions for testing Ark contracts
contract ArkTestHelpers is Test {
    /// @notice Mocks the return value of `totalAssets` for a given Ark contract
    /// @param contractAddress The address of the Ark contract whose `totalAssets` function is to be mocked
    /// @param returnValue The value to return when `totalAssets` is called
    function mockArkTotalAssets(
        address contractAddress,
        uint256 returnValue
    ) public {
        vm.mockCall(
            contractAddress,
            abi.encodeWithSelector(IArk(contractAddress).totalAssets.selector),
            abi.encode(returnValue)
        );
    }

    /**
     * @notice Mocks the return value of `depositCap` for a given Ark contract
     * @param contractAddress The address of the Ark contract whose `totalAssets` function is to be mocked
     * @param returnValue The value to return when `depositCap` is called
     */
    function mockArkMaxAllocation(
        address contractAddress,
        uint256 returnValue
    ) public {
        vm.mockCall(
            contractAddress,
            abi.encodeWithSelector(IArk(contractAddress).depositCap.selector),
            abi.encode(returnValue)
        );
    }

    /**
     * @dev Mocks the `maxRebalanceOutflow` function of the `IArk` contract.
     * @param ark The address of the `IArk` contract.
     * @param maxRebalanceOutflow The value to be passed to the `maxRebalanceOutflow` function.
     */
    function mockArkMaxRebalanceOutflow(
        address ark,
        uint256 maxRebalanceOutflow
    ) internal {
        vm.mockCall(
            ark,
            abi.encodeWithSelector(IArk.maxRebalanceOutflow.selector),
            abi.encode(maxRebalanceOutflow)
        );
    }

    /**
     * @dev Mocks the `maxRebalanceInflow` function of the `IArk` contract.
     * @param ark The address of the `IArk` contract.
     * @param maxRebalanceInflow The value to be passed to the `maxRebalanceInflow` function.
     */
    function mockArkMoveToMax(
        address ark,
        uint256 maxRebalanceInflow
    ) internal {
        vm.mockCall(
            ark,
            abi.encodeWithSelector(IArk.maxRebalanceInflow.selector),
            abi.encode(maxRebalanceInflow)
        );
    }
}
