// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IAsyncFleetGatewayEnums} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEnums.sol";

contract AsyncFleetGatewayConstructorTest is AsyncFleetGatewayTestBase {
    function test_AFG0001_InitialState() public view {
        assertEq(gateway.fleet(), address(fleetMock));
        assertEq(gateway.share(), address(fleetMock));
        assertEq(gateway.asset(), address(assetToken));
        assertEq(gateway.currentDepositEpoch(), 0);
        assertEq(gateway.currentRedeemEpoch(), 0);
        assertEq(
            uint8(gateway.depositEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Open)
        );
        assertEq(
            uint8(gateway.redeemEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Open)
        );
        assertEq(
            uint8(gateway.depositEpochState(1)),
            uint8(IAsyncFleetGatewayEnums.EpochState.NotOpened)
        );
    }

    function test_AFG0002_ReceiptIdEncoding() public view {
        assertEq(gateway.depositReceiptId(0), 0);
        assertEq(gateway.redeemReceiptId(0), 1);
        assertEq(gateway.depositReceiptId(7), 14);
        assertEq(gateway.redeemReceiptId(7), 15);
    }

    function test_AFG0003_SupportsSpecInterfaceIds() public view {
        assertTrue(gateway.supportsInterface(0xe3bc4e65)); // operator
        assertTrue(gateway.supportsInterface(0xce3bbe50)); // async deposit
        assertTrue(gateway.supportsInterface(0x620ee8e4)); // async redeem
        assertTrue(gateway.supportsInterface(0x2f0a18c5)); // ERC-7575 vault
        assertTrue(gateway.supportsInterface(0x01ffc9a7)); // ERC-165 itself
        assertFalse(gateway.supportsInterface(0xffffffff));
    }

    function test_AFG0004_TotalAssetsStartsZero() public view {
        assertEq(gateway.totalAssets(), 0);
    }
}
