// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";
import {Test} from "forge-std/Test.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {SummerVestingWalletsEscrowTestBase} from "./SummerVestingWalletsEscrowTestBase.sol";

/*
 * @title SummerVestingWalletsEscrow Core Tests
 * @dev Test contract for SummerVestingWalletsEscrow contract constructor and core functionality.
 */
contract StakingCoreTest is SummerVestingWalletsEscrowTestBase {
    function test_Constructor_ValidParameters() public {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerVestingWalletsEscrow newStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(address(newStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(newStaking.STAKED_SUMMER_TOKEN()), address(axSumr));
        assertEq(newStaking.vestingFactories().length, 2);
        assertEq(newStaking.getVestingFactory(0), address(factoryVestingV2));
        assertEq(newStaking.getVestingFactory(1), address(factoryVesting));
    }

    function test_Constructor_ZeroProtocolAccessManager() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.InvalidAccessManagerAddress.selector,
                address(0)
            )
        );
        new SummerVestingWalletsEscrow(
            address(0), // Zero protocol access manager
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_ZeroSummerToken() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Summer token address cannot be zero"
            )
        );
        new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(0), // Zero summer token
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_ZeroXSumr() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "StakedSummerToken address cannot be zero"
            )
        );
        new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(0), // Zero StakedSummerToken
            vestingFactories
        );
    }

    function test_Constructor_ZeroVestingFactoryAddress() public {
        address[] memory vestingFactories = new address[](1);
        vestingFactories[0] = address(0); // Zero address in array

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Vesting factory address cannot be zero"
            )
        );
        new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_EmptyVestingFactories() public {
        address[] memory vestingFactories = new address[](0);

        SummerVestingWalletsEscrow newStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 0);
    }

    function test_Constructor_SingleVestingFactory() public {
        address[] memory vestingFactories = new address[](1);
        vestingFactories[0] = address(factoryVestingV2);

        SummerVestingWalletsEscrow newStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 1);
        assertEq(newStaking.getVestingFactory(0), address(factoryVestingV2));
    }

    function test_Constructor_MultipleVestingFactories() public {
        address[] memory vestingFactories = new address[](3);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);
        vestingFactories[2] = address(0x1234); // Mock address

        SummerVestingWalletsEscrow newStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 3);
        for (uint256 i = 0; i < vestingFactories.length; i++) {
            assertEq(newStaking.getVestingFactory(i), vestingFactories[i]);
        }
    }
}
