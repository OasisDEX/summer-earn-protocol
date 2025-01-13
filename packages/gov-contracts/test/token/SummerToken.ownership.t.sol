// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {SupplyControlSummerToken} from "../utils/SupplyControlSummerToken.sol";

contract SummerTokenOwnershipTest is SummerTokenTestBase {
    address public alice;
    address public bob;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_InitialOwnership() public {
        // Check initial owner is set correctly
        assertEq(aSummerToken.owner(), owner);
        assertEq(bSummerToken.owner(), owner);
    }

    function test_TransferOwnership() public {
        vm.startPrank(owner);

        // Test ownership transfer
        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(owner, alice);
        aSummerToken.transferOwnership(alice);

        assertEq(aSummerToken.owner(), alice);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerTransfers() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        aSummerToken.transferOwnership(bob);

        vm.stopPrank();
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        aSummerToken.transferOwnership(address(0));

        vm.stopPrank();
    }

    function test_RenounceOwnership() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(owner, address(0));
        aSummerToken.renounceOwnership();

        assertEq(aSummerToken.owner(), address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerRenounces() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        aSummerToken.renounceOwnership();

        vm.stopPrank();
    }

    function test_OwnershipAfterDeployment() public {
        // Deploy a new token to test initial ownership
        ISummerToken.TokenParams memory params = ISummerToken.TokenParams({
            name: "Test Token",
            symbol: "TEST",
            lzEndpoint: address(endpoints[aEid]),
            initialOwner: alice,
            accessManager: address(accessManagerA),
            initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
            initialYearlyDecayRate: INITIAL_DECAY_RATE_PER_YEAR,
            initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
            transferEnableDate: block.timestamp + 1 days,
            maxSupply: INITIAL_SUPPLY * 10 ** 18,
            initialSupply: INITIAL_SUPPLY * 10 ** 18
        });

        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(address(0), alice);
        SupplyControlSummerToken newToken = new SupplyControlSummerToken(
            params
        );

        assertEq(newToken.owner(), alice);
    }
}
