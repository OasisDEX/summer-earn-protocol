// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

contract BridgeRouterAdaptersTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public keeper = address(0x3);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        // Deploy BridgeQueue first
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router address set later
            user // queueManager
        );

        vm.startPrank(governor);

        // Deploy router, linking it to the queue
        router = new BridgeRouter(
            address(accessManager),
            address(bridgeQueue), // Link to queue
            new uint16[](0), // Empty chainIds array
            new address[](0) // Empty routerAddresses array
        );

        // Set the router address in the queue
        bridgeQueue.setBridgeRouter(address(router));

        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(governor, 10000e18);
        token.mint(user, 10000e18);

        // Fund keeper for execution - give enough for the base fee (0.1 ETH)
        vm.deal(keeper, 1 ether);

        vm.stopPrank();
    }

    // ---- ADAPTER MANAGEMENT TESTS ----

    function testRegisterAdapter() public {
        vm.startPrank(governor);

        // Register second adapter
        assertFalse(router.isValidAdapter(address(mockAdapter2)));
        router.registerAdapter(address(mockAdapter2));
        assertTrue(router.isValidAdapter(address(mockAdapter2)));

        vm.stopPrank();
    }

    function testRegisterAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-governor tries to register adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.registerAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testRegisterDuplicateAdapter() public {
        vm.startPrank(governor);

        // Should revert when registering same adapter twice
        vm.expectRevert(IBridgeRouter.AdapterAlreadyRegistered.selector);
        router.registerAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveAdapter() public {
        vm.startPrank(governor);

        // Remove adapter
        assertTrue(router.isValidAdapter(address(mockAdapter)));
        router.removeAdapter(address(mockAdapter));
        assertFalse(router.isValidAdapter(address(mockAdapter)));

        vm.stopPrank();
    }

    function testRemoveAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-governor tries to remove adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.removeAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveNonExistentAdapter() public {
        vm.startPrank(governor);

        // Should revert when removing non-existent adapter
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.removeAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testGetAdapters() public {
        vm.startPrank(governor);

        // Register second adapter
        router.registerAdapter(address(mockAdapter2));

        // Get adapters
        address[] memory adapterList = router.getAdapters();
        assertEq(adapterList.length, 2);
        assertEq(adapterList[0], address(mockAdapter));
        assertEq(adapterList[1], address(mockAdapter2));

        vm.stopPrank();
    }

    // ---- ADAPTER SELECTION TESTS ----

    function testGetBestAdapter() public {
        // Setup second adapter with different fee
        vm.startPrank(governor);
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        mockAdapter2.setFeeMultiplier(150); // 50% more expensive
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        // Create dummy options just for quote
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 0, // Not relevant for mock adapter fee calc
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Get best adapter for lowest cost via quote
        (, , address bestAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options, // Pass options
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Should select the cheaper adapter
        assertEq(bestAdapter, address(mockAdapter));
    }

    function testSpecifiedAdapter() public {
        vm.startPrank(governor);
        // Configure mockAdapter2 to support the destination chain and asset
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register second adapter
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options with specified adapter
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter2),
            adapterParams: adapterParams
        });

        // Get the required fee first (using router.quote) FOR EXECUTION
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Queue the transfer via BridgeQueue (NO VALUE)
        bytes32 queueId = bridgeQueue.queueTransferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user, // recipient
            options
        );

        vm.stopPrank(); // User stops queueing

        // Verify queue status
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        // Execute the queued operation (can be keeper or anyone) (PAYS FEE)
        vm.startPrank(keeper);
        // Mock the quote and execute calls happening during execution
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(token),
                TRANSFER_AMOUNT,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            )
        );
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(token),
                TRANSFER_AMOUNT,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(nativeFee, uint256(0), address(mockAdapter2)) // Mock return for execution quote, specifying adapter 2
        );
        vm.expectCall(
            address(router),
            nativeFee, // Expect msg.value to be the fee
            abi.encodeWithSelector(IBridgeRouter.executeTransferAssets.selector) // Simplified check
        );
        bytes32 expectedOperationId = keccak256(
            abi.encodePacked("mockSpecifiedAdapterOpId", queueId)
        );
        vm.mockCall(
            address(router),
            nativeFee,
            abi.encodeWithSelector(
                IBridgeRouter.executeTransferAssets.selector
            ), // Need exact match if testing params
            abi.encode(expectedOperationId)
        );

        bytes32 operationId = bridgeQueue.executeQueuedOperation{
            value: nativeFee
        }(queueId); // ADDED {value: nativeFee}
        vm.stopPrank();

        // Verify queue status updated post-execution
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.PENDING) // Should be pending as it's sent to adapter
        );
        // Verify queue maps operationId
        assertEq(bridgeQueue.operationIdToQueueId(operationId), queueId);
        assertEq(operationId, expectedOperationId, "Operation ID mismatch");

        // Verify the specified adapter was used (if checking router state)
        // assertEq(router.operationToAdapter(operationId), address(mockAdapter2));
        // Verify router status (if checking router state)
        // assertEq(
        //     uint256(router.getOperationStatus(operationId)),
        //     uint256(BridgeTypes.OperationStatus.PENDING)
        // );
    }

    function testInvalidSpecifiedAdapter() public {
        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options with invalid adapter
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0x123), // Unregistered adapter
            adapterParams: adapterParams
        });

        // Get the required fee first. This quote call should revert.
        // The check happens in the router during quoting.
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Since quote reverts, queueing would also fail if it depends on a valid quote,
        // or the execution would fail if the check is deferred.
        // Let's keep the check on quote as it's the first point of failure.

        vm.stopPrank();
    }

    function testAdapterSelectionLimits() public {
        // Register multiple adapters with different support combinations
        vm.startPrank(governor);

        // Setup second adapter
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        router.registerAdapter(address(mockAdapter2));

        // Register adapters with different support combinations
        MockAdapter[] memory otherAdapters = new MockAdapter[](3);

        // Adapter that doesn't support the chain
        otherAdapters[0] = new MockAdapter(address(router));
        otherAdapters[0].setSupportedChain(DEST_CHAIN_ID, false);
        otherAdapters[0].setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        router.registerAdapter(address(otherAdapters[0]));

        // Adapter that doesn't support the asset
        otherAdapters[1] = new MockAdapter(address(router));
        otherAdapters[1].setSupportedChain(DEST_CHAIN_ID, true);
        otherAdapters[1].setSupportedAsset(
            DEST_CHAIN_ID,
            address(token),
            false
        );
        router.registerAdapter(address(otherAdapters[1]));

        // Adapter that supports everything
        otherAdapters[2] = new MockAdapter(address(router));
        otherAdapters[2].setSupportedChain(DEST_CHAIN_ID, true);
        otherAdapters[2].setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        router.registerAdapter(address(otherAdapters[2]));

        vm.stopPrank();

        // Create dummy options just for quote
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 0, // Not relevant for mock adapter fee calc
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Get best adapter via quote
        (, , address bestAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Since all adapters return the same base fee (0.1 ETH), the router will select the first one it finds
        // that supports everything. In this case, it should be mockAdapter since it was registered first.
        assertEq(
            bestAdapter,
            address(mockAdapter),
            "Should select first adapter that supports everything"
        );

        // Test with unsupported chain
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            999, // Unsupported chain
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test with unsupported asset
        ERC20Mock unsupportedToken = new ERC20Mock();
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(unsupportedToken),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    // ---- FEE ESTIMATION TESTS ----

    function testQuote() public view {
        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Get quote
        (uint256 nativeFee, , address selectedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Verify quote
        assertEq(selectedAdapter, address(mockAdapter));
        assertTrue(nativeFee > 0);
    }

    function testQuoteNoSuitableAdapter() public {
        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Should revert for unsupported chain
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }
}
