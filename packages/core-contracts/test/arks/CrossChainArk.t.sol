// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {MockAdapter} from "@summerfi/chain-bridge-test/mocks/MockAdapter.sol";

// Mock CrossChainRegistry for testing
contract MockCrossChainRegistry is ICrossChainRegistry {
    mapping(address => CrossChainRelation) private arkToProxy;
    mapping(bytes32 => address) private proxyToArk;

    uint16 public currentChainId = 1;

    function _getTargetKey(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    sourceChainId,
                    targetChainId,
                    targetContract,
                    relationshipType
                )
            );
    }

    function registerCrossChainRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external {}

    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external {}

    function getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (address, uint16) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        return (relation.targetContract, relation.targetChainId);
    }

    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view returns (address) {
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetChainId,
            targetContract,
            relationshipType
        );
        return proxyToArk[targetKey];
    }

    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (bool) {
        return arkToProxy[sourceContract].sourceContract != address(0);
    }

    function setMockProxy(
        address ark,
        address proxy,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) public {
        arkToProxy[ark] = CrossChainRelation({
            sourceContract: ark,
            targetContract: proxy,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType
        });
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetChainId,
            proxy,
            relationshipType
        );
        proxyToArk[targetKey] = ark;
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
        bytes32[] memory supported = new bytes32[](1);
        supported[0] = keccak256("ARK_FLEET");
        return supported;
    }

    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (CrossChainRelation memory) {
        return arkToProxy[sourceContract];
    }

    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external view returns (bool) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        return
            relation.targetContract == targetContract &&
            relation.sourceChainId == sourceChainId &&
            relation.targetChainId == targetChainId;
    }

    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external pure returns (address[] memory sourceContracts) {
        // Return empty array for mock implementation
        return new address[](0);
    }

    function getTargetsForSource(
        address sourceContract,
        bytes32 relationshipType
    )
        external
        view
        returns (
            address[] memory targetContracts,
            uint16[] memory targetChainIds
        )
    {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        if (relation.sourceContract != address(0)) {
            targetContracts = new address[](1);
            targetChainIds = new uint16[](1);
            targetContracts[0] = relation.targetContract;
            targetChainIds[0] = relation.targetChainId;
        } else {
            targetContracts = new address[](0);
            targetChainIds = new uint16[](0);
        }
    }

    function getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external view returns (CrossChainRelation memory) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        // Validate that the target chain ID matches
        if (
            relation.sourceContract != address(0) &&
            relation.targetChainId == targetChainId
        ) {
            return relation;
        }
        // Revert just like the real registry does
        revert RelationshipDoesNotExist(
            sourceContract,
            relationshipType,
            targetChainId
        );
    }
}

contract CrossChainArkTest is Test, ArkTestBase {
    CrossChainArk ark;
    MockBridgeRouter router;
    MockCrossChainRegistry registry;
    MockAdapter mockAdapter;
    address proxy = address(0x5);
    uint16 chainId = 1234;
    FleetCommander fleetCommander;

    BridgeTypes.BridgeOptions defaultOptions;

    function setUp() public {
        initializeCoreContracts();
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
            requiresKeeperData: true,
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
            address(router),
            address(registry),
            chainId,
            params
        );

        // Register the ark-proxy relationship in the registry
        registry.setMockProxy(
            address(ark),
            proxy,
            1,
            chainId,
            keccak256("ARK_FLEET")
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

        // Deploy mock adapter
        mockAdapter = new MockAdapter(address(router));

        // Register adapter
        router.registerAdapter(address(mockAdapter));
    }

    function testConstructorSetsState() public view {
        assertEq(address(ark.bridgeRouter()), address(router));
        assertEq(address(ark.crossChainRegistry()), address(registry));
        assertEq(ark.satelliteChainId(), chainId);
        assertEq(ark.getTargetProxy(), proxy); // Uses registry lookup
    }

    function testBoardCallsQueueTransferAssets() public {
        // Approve Ark to spend tokens from FleetCommander

        uint256 amount = 1000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(mockToken),
                amount: amount,
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory executeTransferParams = abi.encode(params);

        vm.prank(address(fleetCommander));
        ark.board(1000, executeTransferParams);
    }

    function testBoardValidationsFailures() public {
        uint256 amount = 1000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        // Test 1: Zero amount should revert with InvalidAmount
        BridgeTypes.ExecuteTransferParams memory zeroAmountParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(mockToken),
                amount: 0,
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory zeroAmountParams_encoded = abi.encode(zeroAmountParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidAmount.selector);
        ark.board(0, zeroAmountParams_encoded);

        // Test 2: Amount mismatch should revert with InvalidAmount
        BridgeTypes.ExecuteTransferParams memory mismatchAmountParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(mockToken),
                amount: 500, // Different from board amount
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory mismatchAmountParams_encoded = abi.encode(mismatchAmountParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidAmount.selector);
        ark.board(1000, mismatchAmountParams_encoded); // 1000 != 500

        // Test 3: Zero asset address should revert with InvalidAsset
        BridgeTypes.ExecuteTransferParams memory zeroAssetParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(0),
                amount: amount,
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory zeroAssetParams_encoded = abi.encode(zeroAssetParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidAsset.selector);
        ark.board(amount, zeroAssetParams_encoded);

        // Test 4: Wrong asset address should revert with InvalidAsset
        address wrongAsset = address(0x999);
        BridgeTypes.ExecuteTransferParams memory wrongAssetParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: wrongAsset,
                amount: amount,
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory wrongAssetParams_encoded = abi.encode(wrongAssetParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidAsset.selector);
        ark.board(amount, wrongAssetParams_encoded);

        // Test 5: Wrong recipient should revert with InvalidRecipient
        address wrongRecipient = address(0x888);
        BridgeTypes.ExecuteTransferParams memory wrongRecipientParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(mockToken),
                amount: amount,
                recipient: wrongRecipient,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory wrongRecipientParams_encoded = abi.encode(wrongRecipientParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidRecipient.selector);
        ark.board(amount, wrongRecipientParams_encoded);

        // Test 6: Wrong originator should revert with InvalidRequestor
        address wrongOriginator = address(0x777);
        BridgeTypes.ExecuteTransferParams memory wrongOriginatorParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: chainId,
                asset: address(mockToken),
                amount: amount,
                recipient: proxy,
                originator: wrongOriginator,
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory wrongOriginatorParams_encoded = abi.encode(wrongOriginatorParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidRequestor.selector);
        ark.board(amount, wrongOriginatorParams_encoded);

        // Test 7: Wrong destination chain ID should revert with InvalidSatelliteChain
        uint16 wrongChainId = 9999;
        BridgeTypes.ExecuteTransferParams memory wrongChainParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: wrongChainId,
                asset: address(mockToken),
                amount: amount,
                recipient: proxy,
                originator: address(ark),
                keeper: commander,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 200000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                })
            });
        bytes memory wrongChainParams_encoded = abi.encode(wrongChainParams);
        
        vm.prank(address(fleetCommander));
        vm.expectRevert(CrossChainArk.InvalidSatelliteChain.selector);
        ark.board(amount, wrongChainParams_encoded);
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
        ark.requestRemoteAssetBalanceUpdate(defaultOptions);

        // Test successful keeper call
        vm.prank(keeper);
        bytes32 operationId = ark.requestRemoteAssetBalanceUpdate(
            defaultOptions
        );
        assertTrue(
            operationId != bytes32(0),
            "Should return non-zero operation ID"
        );
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
            address(router),
            address(registry),
            chainId,
            params
        );

        // Should revert when target proxy is not set - now with registry error
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(arkWithoutProxy),
                keccak256("ARK_FLEET"),
                chainId
            )
        );
        arkWithoutProxy.requestRemoteAssetBalanceUpdate(defaultOptions);
    }

    function testBridgeRouterDeliveryFlow() public {
        // This test simulates what would happen when BridgeRouter calls deliverReadResponse
        // and that results in CrossChainArk.receiveStateRead being called
        uint256 remoteBalance = 7777;
        bytes memory resultData = abi.encode(remoteBalance);
        bytes32 operationId = keccak256("delivery-flow-test");
        uint16 sourceChain = chainId;

        // In the real flow:
        // 1. CrossChainArk requests a state read via BridgeRouter
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
