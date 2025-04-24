// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

contract BridgeRouterAdminTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockAdapter public mockAdapter;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public guardian = address(0x2);
    address public user = address(0x3);
    address public keeper = address(0x4);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

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
        accessManager.grantGuardianRole(guardian);

        // Deploy BridgeRouter, linking it to the queue
        router = new BridgeRouter(
            address(accessManager),
            address(bridgeQueue), // Link to queue
            new uint16[](0), // Empty chainIds array
            new address[](0) // Empty routerAddresses array
        );

        // Set the router address in the queue
        bridgeQueue.setBridgeRouter(address(router));

        // Deploy mock adapter
        mockAdapter = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(governor, 10000e18);
        token.mint(guardian, 10000e18);
        token.mint(user, 10000e18);

        // Fund keeper for execution
        vm.deal(keeper, 1 ether);

        vm.stopPrank();
    }

    // ---- ADMIN FUNCTION TESTS ----

    function testPauseByGovernor() public {
        vm.startPrank(governor);

        // Pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Unpause
        router.unpause();
        assertFalse(router.paused());

        vm.stopPrank();
    }

    function testPauseByGuardian() public {
        vm.startPrank(guardian);

        // Guardian can pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Guardian cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.unpause();

        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-guardian/governor tries to pause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGuardianOrGovernor.selector,
                user
            )
        );
        router.pause();

        vm.stopPrank();
    }

    function testSendWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        // User attempts to queue
        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

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

        // Get fee estimate first
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        vm.deal(user, nativeFee);

        // Queue the transfer via BridgeQueue - this should succeed
        bytes32 queueId = bridgeQueue.queueTransferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user, // recipient
            options
        );

        vm.stopPrank(); // User stops queueing

        // Attempt to execute the queued operation (e.g., by keeper)
        vm.startPrank(keeper);

        // Execution should revert because the router is paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        bridgeQueue.executeQueuedOperation(queueId);

        vm.stopPrank();
    }

    function testReadStateWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

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

        // Should revert when router is paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.readState(
            DEST_CHAIN_ID,
            address(mockAdapter), // Use mock adapter as target contract
            bytes4(keccak256("test()")), // Example function selector
            "", // Empty params
            options
        );

        vm.stopPrank();
    }

    function testSendMessageWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

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

        // Should revert when router is paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.sendMessage(
            DEST_CHAIN_ID,
            user, // Send to self for testing
            "", // Empty message
            options
        );

        vm.stopPrank();
    }
}
