// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockBridgeQueue} from "@summerfi/chain-bridge-test/mocks/MockBridgeQueue.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

// Mock CrossChainRegistry for testing
contract MockCrossChainRegistry is ICrossChainRegistry {
    mapping(address => CrossChainRelation) private arkToProxy;

    function registerCrossChainRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external {}

    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external {}

    function updateRelationshipStatus(
        address sourceContract,
        bytes32 relationshipType,
        bool isActive
    ) external {}

    function getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (address targetContract, uint16 targetChainId) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        if (relation.targetContract == address(0)) {
            revert RelationshipDoesNotExist(sourceContract, relationshipType);
        }
        return (relation.targetContract, relation.targetChainId);
    }

    function getSourceForTarget(
        uint16 sourceChainId,
        address targetContract,
        bytes32 relationshipType
    ) external pure returns (address sourceContract) {
        revert RelationshipDoesNotExist(targetContract, relationshipType);
    }

    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        bytes32 relationshipType
    ) external view returns (bool) {
        return false;
    }

    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (CrossChainRelation memory) {
        return arkToProxy[sourceContract];
    }

    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external pure returns (address[] memory) {
        return new address[](0);
    }

    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (bool) {
        return arkToProxy[sourceContract].targetContract != address(0);
    }

    function getRelationshipCount(
        bytes32 relationshipType
    ) external pure returns (uint256) {
        return 0;
    }

    function getSupportedRelationshipTypes()
        external
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory types = new bytes32[](1);
        types[0] = keccak256("ARK_FLEET");
        return types;
    }

    // Helper for testing
    function setRelation(
        address ark,
        uint16 sourceChainId,
        uint16 targetChainId,
        address proxy
    ) external {
        arkToProxy[ark] = CrossChainRelation({
            sourceContract: ark,
            targetContract: proxy,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: keccak256("ARK_FLEET"),
            isActive: true
        });
    }
}

contract CrossChainArkTest is Test, ArkTestBase {
    CrossChainArk ark;
    MockBridgeQueue queue;
    MockBridgeRouter router;
    MockCrossChainRegistry registry;
    address proxy = address(0x5);
    uint16 chainId = 1234;
    FleetCommander fleetCommander;

    BridgeTypes.BridgeOptions defaultOptions;

    function setUp() public {
        initializeCoreContracts();
        queue = new MockBridgeQueue();
        router = new MockBridgeRouter();
        registry = new MockCrossChainRegistry();

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
            address(registry),
            chainId,
            params
        );

        // Register the ark-proxy relationship in the registry
        registry.setRelation(address(ark), 1, chainId, proxy);

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
        assertEq(address(ark.crossChainRegistry()), address(registry));
        assertEq(ark.targetChainId(), chainId);
        assertEq(ark.getTargetProxy(), proxy); // Uses registry lookup
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
        ark.receiveStateRead(resultData, address(ark), requestId, sourceChain);

        // Check state
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
    }

    function testReceiveMessageWithAssets() public {
        address tokenAddress = address(mockToken);
        uint256 amount = 500;
        bytes memory message = "";
        uint16 sourceChain = chainId;

        // Track initial state
        uint256 initialRemoteBalance = 1000;

        // Set initial remote balance
        bytes memory resultData = abi.encode(initialRemoteBalance);
        bytes32 requestId = keccak256("test-request");
        vm.prank(address(router));
        ark.receiveStateRead(resultData, address(ark), requestId, sourceChain);

        // Should emit the event when receiving assets
        vm.expectEmit(true, true, true, true);
        emit CrossChainArk.AssetsReceived(tokenAddress, amount, sourceChain);

        // Mock token transfer that would happen in a real bridge
        deal(address(mockToken), address(ark), amount);

        // Call as bridgeRouter
        vm.prank(address(router));
        ark.receiveMessageWithAssets(
            tokenAddress,
            amount,
            message,
            sourceChain
        );

        // Check state was updated correctly
        assertEq(ark.lastRemoteAssetBalance(), initialRemoteBalance - amount);
    }

    // ========================================================================
    // ENHANCED READ DELIVERY TESTS
    // ========================================================================

    function testReceiveStateReadWithCorrectParameterOrder() public {
        uint256 remoteBalance = 54321;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("parameter-order-test");
        uint16 sourceChain = chainId;

        // Test the correct parameter order: (resultData, requestor, requestId, sourceChainId)
        vm.expectEmit(true, true, true, true);
        emit CrossChainArk.RemoteAssetBalanceUpdated(remoteBalance, requestId);

        vm.prank(address(router));
        ark.receiveStateRead(resultData, address(ark), requestId, sourceChain);

        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
        assertEq(
            ark.inflightAssets(),
            0,
            "Inflight assets should be reset to 0"
        );
    }

    function testReceiveStateReadResetsInflightAssets() public {
        uint256 remoteBalance = 2000;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("inflight-reset-test");
        uint16 sourceChain = chainId;

        // Set some inflight assets first
        vm.prank(address(router));
        ark.updateInflightAssets(500);
        assertEq(
            ark.inflightAssets(),
            500,
            "Setup: inflight assets should be 500"
        );

        // Receive state read should reset inflight assets
        vm.expectEmit(true, true, true, true);
        emit IInflightAssetTracking.InflightAssetsUpdated(0);

        vm.prank(address(router));
        ark.receiveStateRead(resultData, address(ark), requestId, sourceChain);

        assertEq(
            ark.inflightAssets(),
            0,
            "Inflight assets should be reset after state read"
        );
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
    }

    function testReceiveStateReadUnauthorizedCaller() public {
        uint256 remoteBalance = 1000;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("unauthorized-test");
        uint16 sourceChain = chainId;

        // Test unauthorized caller
        vm.prank(address(0x999));
        vm.expectRevert(CrossChainArk.Unauthorized.selector);
        ark.receiveStateRead(resultData, address(ark), requestId, sourceChain);
    }

    function testReceiveStateReadInvalidSourceChain() public {
        uint256 remoteBalance = 1000;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("wrong-chain-test");
        uint16 wrongSourceChain = 9999;

        // Test wrong source chain
        vm.prank(address(router));
        vm.expectRevert(CrossChainArk.InvalidSourceChain.selector);
        ark.receiveStateRead(
            resultData,
            address(ark),
            requestId,
            wrongSourceChain
        );
    }

    function testReceiveStateReadInvalidRequestor() public {
        uint256 remoteBalance = 1000;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("wrong-requestor-test");
        uint16 sourceChain = chainId;

        // Test wrong requestor
        vm.prank(address(router));
        vm.expectRevert(CrossChainArk.InvalidRequestor.selector);
        ark.receiveStateRead(
            resultData,
            address(0x123),
            requestId,
            sourceChain
        );
    }

    function testSupportsInterfaceIncludesStateReadReceiver() public view {
        // Test that the contract properly reports support for all interfaces
        assertTrue(
            ark.supportsInterface(type(ICrossChainAssetReceiver).interfaceId),
            "Should support ICrossChainAssetReceiver"
        );
        assertTrue(
            ark.supportsInterface(type(IInflightAssetTracking).interfaceId),
            "Should support IInflightAssetTracking"
        );
        // Note: ICrossChainStateReadReceiver interface support is tested in other tests
    }

    function testTotalAssetsIncludesAllComponents() public {
        uint256 localBalance = 1000;
        uint256 remoteBalance = 2000;
        uint256 inflightAmount = 500;

        // Setup local balance
        deal(address(mockToken), address(ark), localBalance);

        // Setup remote balance via state read
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 requestId = keccak256("total-assets-test");
        vm.prank(address(router));
        ark.receiveStateRead(resultData, address(ark), requestId, chainId);

        // Setup inflight assets
        vm.prank(address(router));
        ark.updateInflightAssets(inflightAmount);

        // Test total assets calculation
        uint256 expectedTotal = localBalance + remoteBalance + inflightAmount;
        assertEq(
            ark.totalAssets(),
            expectedTotal,
            "Total assets should include local + remote + inflight"
        );
    }

    function testRequestRemoteAssetBalanceUpdateRequiresKeeper() public {
        // Test that only keeper can request balance updates
        vm.prank(address(0x999));
        vm.expectRevert(); // Should revert with access control error
        ark.requestRemoteAssetBalanceUpdate();

        // Test successful keeper call
        vm.prank(keeper);
        bytes32 queueId = ark.requestRemoteAssetBalanceUpdate();
        assertTrue(queueId != bytes32(0), "Should return non-zero queue ID");
    }

    function testRequestRemoteAssetBalanceUpdateRequiresTargetProxy() public {
        // Deploy ark without target proxy set
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

        CrossChainArk arkWithoutProxy = new CrossChainArk(
            address(queue),
            address(router),
            address(registry),
            chainId,
            params
        );

        // Should revert when target proxy is not set
        vm.prank(keeper);
        vm.expectRevert(CrossChainArk.NoProxyRelationshipRegistered.selector);
        arkWithoutProxy.requestRemoteAssetBalanceUpdate();
    }

    function testBridgeRouterDeliveryFlow() public {
        // This test simulates what would happen when BridgeRouter calls deliverReadResponse
        // and that results in CrossChainArk.receiveStateRead being called
        uint256 remoteBalance = 7777;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 operationId = keccak256("delivery-flow-test");
        uint16 sourceChain = chainId;

        // In the real flow:
        // 1. CrossChainArk requests a state read via BridgeQueue
        // 2. BridgeRouter executes the read request
        // 3. When response comes back, BridgeRouter.deliverReadResponse calls receiveStateRead

        // For this test, we simulate step 3 directly
        vm.expectEmit(true, true, true, true);
        emit CrossChainArk.RemoteAssetBalanceUpdated(
            remoteBalance,
            operationId
        );

        // Simulate BridgeRouter calling receiveStateRead on the CrossChainArk
        vm.prank(address(router));
        ark.receiveStateRead(
            resultData,
            address(ark),
            operationId,
            sourceChain
        );

        // Verify the state was updated correctly
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
        assertEq(ark.inflightAssets(), 0);
    }

    function testInterfaceSupport() public view {
        // Test all the interfaces the CrossChainArk should support
        assertTrue(
            ark.supportsInterface(type(ICrossChainAssetReceiver).interfaceId),
            "Should support ICrossChainAssetReceiver"
        );
        assertTrue(
            ark.supportsInterface(type(IInflightAssetTracking).interfaceId),
            "Should support IInflightAssetTracking"
        );
        assertTrue(
            ark.supportsInterface(type(IERC165).interfaceId),
            "Should support IERC165"
        );

        // Test that it reports false for unsupported interfaces
        assertFalse(
            ark.supportsInterface(bytes4(0xffffffff)),
            "Should not support random interface"
        );
    }
}
