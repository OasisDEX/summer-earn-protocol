// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IERC7540Deposit} from "../../src/interfaces/async-gateway/IERC7540.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

contract AsyncFleetGatewayRequestDepositTest is AsyncFleetGatewayTestBase {
    function test_AFG0201_RequestDepositHappyPath() public {
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(alice, alice, 0, alice, 100e6);
        uint256 requestId = _requestDeposit(alice, 100e6);

        assertEq(requestId, 0);
        assertEq(assetToken.balanceOf(address(gateway)), 100e6);
        assertEq(gateway.balanceOf(alice, gateway.depositReceiptId(0)), 100e6);
        assertEq(gateway.pendingDepositRequest(0, alice), 100e6);
        assertEq(gateway.claimableDepositRequest(0, alice), 0);
    }

    function test_AFG0202_RequestDepositForOtherController() public {
        vm.prank(alice);
        gateway.requestDeposit(50e6, bob, alice); // alice pays, bob controls
        assertEq(gateway.balanceOf(bob, gateway.depositReceiptId(0)), 50e6);
        assertEq(gateway.pendingDepositRequest(0, bob), 50e6);
        assertEq(gateway.pendingDepositRequest(0, alice), 0);
    }

    function test_AFG0203_OperatorMayRequestForOwner() public {
        vm.prank(alice);
        gateway.setOperator(bob, true);
        vm.prank(bob);
        gateway.requestDeposit(25e6, alice, alice); // bob spends alice's assets as operator
        assertEq(gateway.pendingDepositRequest(0, alice), 25e6);
    }

    function test_AFG0204_NonOperatorCannotSpendOwner() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidOperator.selector, alice, bob)
        );
        gateway.requestDeposit(25e6, alice, alice);
    }

    function test_AFG0205_ZeroAssetsReverts() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        gateway.requestDeposit(0, alice, alice);
    }

    function test_AFG0206_WhitelistEnforced() public {
        vm.prank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelistOpen(
            address(fleetMock),
            false
        );
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(fleetMock),
                alice
            )
        );
        gateway.requestDeposit(10e6, alice, alice);
    }

    function test_AFG0207_SecondEpochGetsOwnReceiptId() public {
        _requestDeposit(alice, 10e6);
        vm.prank(keeper);
        gateway.closeDepositEpoch();
        uint256 id2 = _requestDeposit(alice, 20e6);
        assertEq(id2, 1);
        assertEq(gateway.balanceOf(alice, gateway.depositReceiptId(1)), 20e6);
        assertEq(gateway.pendingDepositRequest(1, alice), 20e6);
        // epoch 0 still pending (InSettlement, not Settled)
        assertEq(gateway.pendingDepositRequest(0, alice), 10e6);
    }
}
