// SPDX-License-Identifier: BUSL-1.1
import {IArk} from "../../src/interfaces/IArk.sol";
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
}
