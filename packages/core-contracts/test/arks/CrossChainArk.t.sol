// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockBridgeQueue} from "@summerfi/chain-bridge-test/mocks/MockBridgeQueue.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract CrossChainArkTest is Test, ArkTestBase {
    CrossChainArk ark;
    MockBridgeQueue queue;
    MockBridgeRouter router;
    address proxy = address(0x5);
    uint16 chainId = 1234;

    BridgeTypes.BridgeOptions defaultOptions;

    function setUp() public {
        initializeCoreContracts();
        queue = new MockBridgeQueue();
        router = new MockBridgeRouter();

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: 10000 // 100%
        });

        defaultOptions = BridgeTypes.BridgeOptions({gasLimit: 0, params: ""});

        ark = new CrossChainArk(
            address(accessManager),
            address(queue),
            address(router),
            chainId,
            proxy,
            defaultOptions,
            params
        );
    }

    function testConstructorSetsState() public {
        assertEq(address(ark.bridgeQueue()), address(queue));
        assertEq(address(ark.bridgeRouter()), address(router));
        assertEq(ark.targetChainId(), chainId);
        assertEq(ark.targetProxy(), proxy);
    }

    function testBoardCallsQueueTransferAssets() public {
        ark._board(1000, "");
        assertEq(queue.lastDestinationChainId(), chainId);
        assertEq(queue.lastAsset(), address(mockToken));
        assertEq(queue.lastAmount(), 1000);
        assertEq(queue.lastRecipient(), proxy);
    }

    function testDisembarkCallsQueueSendMessage() public {
        ark._disembark(500, "");
        assertEq(queue.lastDestinationChainId(), chainId);
        assertEq(queue.lastRecipient(), proxy);
        assertEq(abi.decode(queue.lastMessage(), (uint256)), 500);
    }
}
