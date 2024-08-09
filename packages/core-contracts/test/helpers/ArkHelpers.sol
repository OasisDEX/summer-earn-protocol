// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IArk} from "../../src/interfaces/IArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {Constants} from "./Constants.sol";

/// @title Ark Test Helpers
/// @notice Provides helper functions for testing Ark contracts
contract ArkTestHelpers is Test, Constants {
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
     * @notice Mocks the return value of `rate` for a given Ark contract
     * @param ark The address of the Ark contract whose `rate` function is to be mocked
     * @param rate The value to return when `rate` is called
     */
    function mockArkRate(address ark, uint256 rate) internal {
        vm.mockCall(ark, abi.encodeWithSignature("rate()"), abi.encode(rate));
    }

    /**
     * @dev Mocks the `moveFromMax` function of the `IArk` contract.
     * @param ark The address of the `IArk` contract.
     * @param moveFromMax The value to be passed to the `moveFromMax` function.
     */
    function mockArkMoveFromMax(address ark, uint256 moveFromMax) internal {
        vm.mockCall(
            ark,
            abi.encodeWithSelector(IArk.moveFromMax.selector),
            abi.encode(moveFromMax)
        );
    }

    /**
     * @dev Mocks the `moveToMax` function of the `IArk` contract.
     * @param ark The address of the `IArk` contract.
     * @param moveToMax The value to be passed to the `moveToMax` function.
     */
    function mockArkMoveToMax(address ark, uint256 moveToMax) internal {
        vm.mockCall(
            ark,
            abi.encodeWithSelector(IArk.moveToMax.selector),
            abi.encode(moveToMax)
        );
    }

    function test() public {}
}
