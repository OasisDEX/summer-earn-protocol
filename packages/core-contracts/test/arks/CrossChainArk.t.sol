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
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";

contract CrossChainArkTest is Test, ArkTestBase {
    CrossChainArk ark;
    MockBridgeQueue queue;
    MockBridgeRouter router;
    address proxy = address(0x5);
    uint16 chainId = 1234;
    FleetCommander fleetCommander;

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
            maxDepositPercentageOfTVL: PERCENTAGE_1
        });

        defaultOptions = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            adapterParams: BridgeTypes.AdapterParams({
                gasLimit: 0,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            })
        });

        ark = new CrossChainArk(
            address(queue),
            address(router),
            chainId,
            proxy,
            defaultOptions,
            params
        );

        // Set up FleetCommander with BufferArk
        (address fleetCommanderAddress, ) = setupFleetCommanderWithBufferArk(
            address(mockToken),
            PERCENTAGE_1,
            "TestFleet"
        );
        fleetCommander = FleetCommander(fleetCommanderAddress);

        // Grant commander role to FleetCommander
        vm.prank(governor);
        accessManager.grantCommanderRole(address(ark), address(fleetCommander));

        // Activate the Ark
        vm.prank(governor);
        fleetCommander.addArk(address(ark));
    }

    function testConstructorSetsState() public view {
        assertEq(address(ark.bridgeQueue()), address(queue));
        assertEq(address(ark.bridgeRouter()), address(router));
        assertEq(ark.targetChainId(), chainId);
        assertEq(ark.targetProxy(), proxy);
    }

    function testBoardCallsQueueTransferAssets() public {
        // Approve Ark to spend tokens from FleetCommander
        deal(address(mockToken), address(fleetCommander), 1000);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        vm.prank(address(fleetCommander));
        ark.board(1000, "");
        assertEq(queue.lastDestinationChainId(), chainId);
        assertEq(queue.lastAsset(), address(mockToken));
        assertEq(queue.lastAmount(), 1000);
        assertEq(queue.lastRecipient(), proxy);
    }

    function testDisembarkCallsQueueSendMessage() public {
        deal(address(mockToken), address(ark), 1000);

        vm.prank(address(fleetCommander));
        ark.disembark(500, "");
        assertEq(queue.lastDestinationChainId(), chainId);
        assertEq(queue.lastRecipient(), proxy);
        assertEq(abi.decode(queue.lastMessage(), (uint256)), 500);
    }

    function testReceiveStateReadUpdatesRemoteBalanceAndEmitsEvent() public {
        uint256 remoteBalance = 12345;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("test-request");
        uint16 sourceChain = chainId;

        // Should emit the event and update the state
        vm.expectEmit(true, true, true, true);
        emit CrossChainArk.RemoteAssetBalanceUpdated(remoteBalance, requestId);

        // Call as bridgeRouter, with correct sourceChain and requestor
        vm.prank(address(router));
        ark.receiveStateRead(resultData, address(ark), sourceChain, requestId);

        // Check state
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
    }
}
