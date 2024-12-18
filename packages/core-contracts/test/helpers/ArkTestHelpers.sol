// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../../src/interfaces/IArk.sol";
import {IArkConfigProvider} from "../../src/interfaces/IArkConfigProvider.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {Test, console} from "forge-std/Test.sol";

/// @title Ark Test Helpers
/// @notice Provides helper functions for testing Ark contracts
contract ArkTestHelpers is Test {
    /// @notice Mocks the return value of `totalAssets` for a given Ark contract
    /// @param contractAddress The address of the Ark contract whose `totalAssets` function is to be mocked
    /// @param returnValue The value to return when `totalAssets` is called
    function _mockArkTotalAssets(
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
    function _mockArkMaxAllocation(
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
            abi.encodeWithSelector(
                IArkConfigProvider.maxRebalanceOutflow.selector
            ),
            abi.encode(maxRebalanceOutflow)
        );
    }

    /**
     * @dev Mocks the `maxRebalanceInflow` function of the `IArk` contract.
     * @param ark The address of the `IArk` contract.
     * @param maxRebalanceInflow The value to be passed to the `maxRebalanceInflow` function.
     */
    function _mockArkMoveToMax(
        address ark,
        uint256 maxRebalanceInflow
    ) internal {
        vm.mockCall(
            ark,
            abi.encodeWithSelector(
                IArkConfigProvider.maxRebalanceInflow.selector
            ),
            abi.encode(maxRebalanceInflow)
        );
    }

    /**
     * @notice Mocks the `isArkActiveOrBufferArk` function of the `IFleetCommander` contract.
     * @param commanderAddress The address of the `IFleetCommander` contract.
     * @param arkAddress The address of the Ark contract.
     * @param isActive The value to be passed to the `isArkActiveOrBufferArk` function.
     */
    function _mockIsArkActive(
        address commanderAddress,
        address arkAddress,
        bool isActive
    ) internal {
        vm.mockCall(
            commanderAddress,
            abi.encodeWithSelector(
                IFleetCommanderConfigProvider.isArkActiveOrBufferArk.selector,
                arkAddress
            ),
            abi.encode(isActive)
        );
    }

    function _mockBufferArk(
        address commanderAddress,
        address bufferArk
    ) internal {
        vm.mockCall(
            commanderAddress,
            abi.encodeWithSelector(
                IFleetCommanderConfigProvider.bufferArk.selector
            ),
            abi.encode(bufferArk)
        );
    }

    /**
     * @notice Mocks the `commander` function of the `IArk` contract.
     * @param arkAddress The address of the `IArk` contract.
     * @param commanderAddress The address to be returned by the `commander` function.
     */
    function _mockArkCommander(
        address arkAddress,
        address commanderAddress
    ) internal {
        vm.mockCall(
            arkAddress,
            abi.encodeWithSelector(IArkConfigProvider.commander.selector),
            abi.encode(commanderAddress)
        );
    }
}
