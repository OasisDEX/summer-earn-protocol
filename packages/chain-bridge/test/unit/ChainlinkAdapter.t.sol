// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "../../src/adapters/ChainlinkAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockChainlinkRouter} from "../mocks/MockChainlinkRouter.sol";

contract ChainlinkAdapterTest is Test {
    ChainlinkAdapter public adapter;
    MockChainlinkRouter public router;
    ERC20Mock public token;

    address public bridgeRouter = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        router = new MockChainlinkRouter();
        token = new ERC20Mock();

        vm.startPrank(bridgeRouter);
        adapter = new ChainlinkAdapter();
        vm.stopPrank();

        // Setup will be expanded as implementation details are defined
    }

    function testTransferAsset() public {
        // Test sending assets through the adapter
    }

    function testEstimateFee() public {
        // Test fee estimation
    }

    function testReceiveMessage() public {
        // Test receiving a message from Chainlink
    }
}
