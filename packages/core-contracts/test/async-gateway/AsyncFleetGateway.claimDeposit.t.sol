// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";

contract AsyncFleetGatewayClaimDepositTest is AsyncFleetGatewayTestBase {
    function test_AFG0401_ClaimFullDeposit() public {
        _requestDeposit(alice, 100e6);
        uint256 epoch = _closeAndSettleDeposit();
        uint256 expectedShares = gateway.maxMint(alice);

        vm.expectEmit(true, true, false, true);
        emit Deposit(alice, alice, 100e6, expectedShares);
        vm.prank(alice);
        uint256 shares = gateway.deposit(100e6, alice, alice);

        assertEq(shares, expectedShares);
        assertEq(fleetMock.balanceOf(alice), expectedShares);
        assertEq(gateway.balanceOf(alice, gateway.depositReceiptId(epoch)), 0);
        assertEq(gateway.maxDeposit(alice), 0);
    }

    function test_AFG0402_PartialClaimThenRest() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();

        vm.prank(alice);
        uint256 s1 = gateway.deposit(40e6, alice, alice);
        assertEq(gateway.maxDeposit(alice), 60e6);
        vm.prank(alice);
        uint256 s2 = gateway.deposit(60e6, alice, alice);
        assertEq(gateway.maxDeposit(alice), 0);
        assertEq(fleetMock.balanceOf(alice), s1 + s2);
    }

    function test_AFG0403_FifoAcrossEpochsWithDifferentRates() public {
        // epoch 0 at 1:1
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        // epoch 1 at 2 assets/share
        fleetMock.setAssetsPerShare(2e18);
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();

        uint256 sharesE0 = gateway.depositRate(0).baseAmount; // for 100e6 in
        uint256 sharesE1 = gateway.depositRate(1).baseAmount;
        assertGt(sharesE0, sharesE1); // rate really differs

        // claim 150e6: consumes all of epoch 0 (100e6) + 50e6 of epoch 1
        vm.prank(alice);
        uint256 shares = gateway.deposit(150e6, alice, alice);
        assertEq(shares, sharesE0 + (sharesE1 / 2));
        assertEq(gateway.claimableDepositRequest(0, alice), 0);
        assertEq(gateway.claimableDepositRequest(1, alice), 50e6);
    }

    function test_AFG0404_ClaimBeforeSettleReverts() public {
        _requestDeposit(alice, 100e6);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ExceededMaxClaim.selector, alice, 100e6, 0)
        );
        gateway.deposit(100e6, alice, alice);
    }

    function test_AFG0405_OverClaimReverts() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExceededMaxClaim.selector,
                alice,
                101e6,
                100e6
            )
        );
        gateway.deposit(101e6, alice, alice);
    }

    function test_AFG0406_OperatorClaimsForController() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        vm.prank(alice);
        gateway.setOperator(bob, true);
        vm.prank(bob);
        uint256 shares = gateway.deposit(100e6, bob, alice); // bob claims alice's request to himself
        assertEq(fleetMock.balanceOf(bob), shares);
    }

    function test_AFG0407_StrangerCannotClaim() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidOperator.selector, alice, bob)
        );
        gateway.deposit(100e6, bob, alice);
    }

    function test_AFG0408_MintExactShares() public {
        fleetMock.setAssetsPerShare(3e18);
        _requestDeposit(alice, 90e6);
        _closeAndSettleDeposit();

        uint256 allShares = gateway.maxMint(alice);
        uint256 half = allShares / 2;
        vm.prank(alice);
        uint256 assetsUsed = gateway.mint(half, alice, alice);
        assertEq(fleetMock.balanceOf(alice), half);
        assertGe(assetsUsed, 1);
        // consuming the remainder always works
        uint256 remainderShares = gateway.maxMint(alice);
        vm.prank(alice);
        gateway.mint(remainderShares, alice, alice);
        assertEq(gateway.maxMint(alice), 0);
    }

    function test_AFG0409_TwoArgOverloadUsesSenderAsController() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        vm.prank(alice);
        gateway.deposit(100e6, alice);
        assertEq(gateway.maxDeposit(alice), 0);
    }

    function test_AFG0410_ClaimWhitelistEnforced() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
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
        gateway.deposit(100e6, alice, alice);
    }

    function test_AFG0411_TransferredReceiptMovesClaim() public {
        _requestDeposit(alice, 100e6);
        uint256 epoch = _closeAndSettleDeposit();
        uint256 receiptId = gateway.depositReceiptId(epoch);
        vm.prank(alice);
        gateway.safeTransferFrom(alice, bob, receiptId, 100e6, "");
        assertEq(gateway.maxDeposit(alice), 0);
        assertEq(gateway.maxDeposit(bob), 100e6);
        vm.prank(bob);
        uint256 shares = gateway.deposit(100e6, bob, bob);
        assertEq(fleetMock.balanceOf(bob), shares);
    }
}
