// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";

contract AsyncFleetGatewayTransfersTest is AsyncFleetGatewayTestBase {
    function test_AFG0901_WhitelistedTransferOk() public {
        _requestDeposit(alice, 100e6);
        uint256 receiptId = gateway.depositReceiptId(0);
        vm.prank(alice);
        gateway.safeTransferFrom(alice, bob, receiptId, 40e6, "");
        assertEq(gateway.pendingDepositRequest(0, bob), 40e6);
        assertEq(gateway.pendingDepositRequest(0, alice), 60e6);
    }

    function test_AFG0902_NonWhitelistedReceiverBlocked() public {
        _requestDeposit(alice, 100e6);
        uint256 receiptId = gateway.depositReceiptId(0);
        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelistOpen(
            address(fleetMock),
            false
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(fleetMock),
            alice,
            true
        );
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(fleetMock),
                bob
            )
        );
        gateway.safeTransferFrom(alice, bob, receiptId, 40e6, "");
    }

    function test_AFG0903_BatchTransferGated() public {
        _requestDeposit(alice, 100e6);
        uint256[] memory ids = new uint256[](1);
        ids[0] = gateway.depositReceiptId(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 10e6;

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
        gateway.safeBatchTransferFrom(alice, bob, ids, amts, "");
    }
}
