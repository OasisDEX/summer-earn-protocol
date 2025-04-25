// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "../../src/adapters/ChainlinkAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ChainlinkAdapterTest is Test {
    ChainlinkAdapter public adapter;
    ERC20Mock public token;

    address public bridgeRouter = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        token = new ERC20Mock();

        vm.startPrank(bridgeRouter);
        adapter = new ChainlinkAdapter();
        vm.stopPrank();

        // Setup will be expanded as implementation details are defined
    }

    function testTransferAsset() public {
        // Test that transferAsset reverts with OperationNotSupported
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapter.transferAsset(
            1, // destinationChainId
            address(token), // asset
            user, // recipient
            100, // amount
            user, // originator
            BridgeTypes.AdapterParams({
                gasLimit: 0,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            })
        );
    }

    function testEstimateFee() public {
        // Test that estimateFee reverts with OperationNotSupported
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapter.estimateFee(
            1, // destinationChainId
            address(token), // asset
            100, // amount
            BridgeTypes.AdapterParams({
                gasLimit: 0,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function testReceiveMessage() public {
        // Test that ccipReceive reverts with OperationNotSupported
        vm.expectRevert(IBridgeAdapter.OperationNotSupported.selector);
        adapter.ccipReceive(
            bytes32(0), // messageId
            "" // payload
        );
    }
}
