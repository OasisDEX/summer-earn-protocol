// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerTokenErrors} from "../../src/errors/ISummerTokenErrors.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {SupplyControlSummerToken} from "../utils/SupplyControlSummerToken.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";

contract SummerTokenOwnershipTest is SummerTokenTestBase {
    address public alice;
    address public bob;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_InitialOwnership() public view {
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
        ISummerToken.ConstructorParams memory constructorParams = ISummerToken
            .ConstructorParams({
                name: "Test Token",
                symbol: "TEST",
                lzEndpoint: address(endpoints[aEid]),
                initialOwner: alice,
                accessManager: address(accessManagerA),
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                transferEnableDate: block.timestamp + 1 days,
                hubChainId: 31337
            });

        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(address(0), alice);
        SupplyControlSummerToken newToken = new SupplyControlSummerToken(
            constructorParams
        );

        address summerVestingWalletFactory = address(
            new SummerVestingWalletFactory(
                address(newToken),
                address(accessManagerA)
            )
        );

        ISummerToken.InitializeParams memory initializeParams = ISummerToken
            .InitializeParams({
                initialSupply: INITIAL_SUPPLY * 10 ** 18,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialYearlyDecayRate: INITIAL_DECAY_RATE_PER_YEAR,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                vestingWalletFactory: summerVestingWalletFactory
            });

        vm.prank(alice);
        newToken.initialize(initializeParams);

        assertEq(newToken.owner(), alice);
    }

    function test_RevertWhen_AlreadyInitialized() public {
        ISummerToken.ConstructorParams memory constructorParams = ISummerToken
            .ConstructorParams({
                name: "Test Token",
                symbol: "TEST",
                lzEndpoint: address(endpoints[aEid]),
                initialOwner: owner,
                accessManager: address(accessManagerA),
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                transferEnableDate: block.timestamp + 1 days,
                hubChainId: 31337
            });

        SupplyControlSummerToken newToken = new SupplyControlSummerToken(
            constructorParams
        );

        address summerVestingWalletFactory = address(
            new SummerVestingWalletFactory(
                address(newToken),
                address(accessManagerA)
            )
        );
        ISummerToken.InitializeParams memory initializeParams = ISummerToken
            .InitializeParams({
                initialSupply: INITIAL_SUPPLY * 10 ** 18,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialYearlyDecayRate: INITIAL_DECAY_RATE_PER_YEAR,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                vestingWalletFactory: summerVestingWalletFactory
            });

        // First initialization should succeed
        vm.prank(owner);
        newToken.initialize(initializeParams);

        // Second initialization should fail
        vm.prank(owner);
        vm.expectRevert(ISummerTokenErrors.AlreadyInitialized.selector);
        newToken.initialize(initializeParams);
    }

    function test_OwnershipAfterDeploymentAndInitialization() public {
        ISummerToken.ConstructorParams memory constructorParams = ISummerToken
            .ConstructorParams({
                name: "Test Token",
                symbol: "TEST",
                lzEndpoint: address(endpoints[aEid]),
                initialOwner: alice,
                accessManager: address(accessManagerA),
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                transferEnableDate: block.timestamp + 1 days,
                hubChainId: 31337
            });

        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(address(0), alice);
        SupplyControlSummerToken newToken = new SupplyControlSummerToken(
            constructorParams
        );

        address summerVestingWalletFactory = address(
            new SummerVestingWalletFactory(
                address(newToken),
                address(accessManagerA)
            )
        );

        ISummerToken.InitializeParams memory initializeParams = ISummerToken
            .InitializeParams({
                initialSupply: INITIAL_SUPPLY * 10 ** 18,
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialYearlyDecayRate: INITIAL_DECAY_RATE_PER_YEAR,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                vestingWalletFactory: summerVestingWalletFactory
            });

        // Verify owner is set correctly after deployment
        assertEq(newToken.owner(), alice);

        // Initialize with owner
        vm.prank(alice);
        newToken.initialize(initializeParams);

        // Verify owner remains the same after initialization
        assertEq(newToken.owner(), alice);
    }
}
