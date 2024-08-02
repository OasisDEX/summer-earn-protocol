// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IArk} from "../../src/interfaces/IArk.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title Ark Test Helpers
 * @notice Provides helper functions for testing Ark contracts
 */
contract ArkTestHelpers is Test {
    /**
     * @notice Mocks the return value of `totalAssets` for a given Ark contract
     * @param contractAddress The address of the Ark contract whose `totalAssets` function is to be mocked
     * @param returnValue The value to return when `totalAssets` is called
     */
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
     * @notice Mocks the return value of `maxAllocation` for a given Ark contract
     * @param contractAddress The address of the Ark contract whose `totalAssets` function is to be mocked
     * @param returnValue The value to return when `maxAllocation` is called
     */
    function mockArkMaxAllocation(
        address contractAddress,
        uint256 returnValue
    ) public {
        vm.mockCall(
            contractAddress,
            abi.encodeWithSelector(
                IArk(contractAddress).maxAllocation.selector
            ),
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
}
