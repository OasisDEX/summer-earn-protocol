// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract BridgeRouterTransferTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x3);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    // Add these constants to each test file
    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    function setUp() public {
        vm.startPrank(governor);

        // Deploy contracts
        accessManager = new ProtocolAccessManager(governor);
        router = new BridgeRouter(
            address(accessManager),
            new uint16[](0), // Empty chainIds array
            new address[](0) // Empty routerAddresses array
        );
        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(user, 10000e18);

        vm.stopPrank();
    }

    // ---- TRANSFER ASSET TESTS ----

    function testSend() public {
        // Deal ETH to the user - need enough to cover the fee
        vm.deal(user, 3000 ether);

        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Get a quote first to determine the required fee
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options
        );

        // Send transfer with the quoted fee
        bytes32 operationId = router.transferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Verify transfer was initiated
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );
        assertEq(router.operationToAdapter(operationId), address(mockAdapter));

        vm.stopPrank();
    }

    function testSendInvalidParams() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Should revert with zero amount
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.transferAssets(DEST_CHAIN_ID, address(token), 0, user, options);

        // Should revert with zero recipient
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            address(0),
            options
        );

        vm.stopPrank();
    }

    function testSendNoSuitableAdapter() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Unsupported destination chain
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.transferAssets(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();
    }

    function testUpdateTransferStatus() public {
        // Deal ETH to the user - need enough to cover the fee
        vm.deal(user, 3000 ether);

        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Get a quote first to determine the required fee
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options
        );

        // Send transfer
        bytes32 operationId = router.transferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();

        // Update status from adapter
        vm.prank(address(mockAdapter));
        router.updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        // Verify status was updated
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.DELIVERED)
        );
    }

    function testUpdateTransferStatusUnauthorized() public {
        // Deal ETH to the user - need enough to cover the fee
        vm.deal(user, 3000 ether);

        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Get a quote first to determine the required fee
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options
        );

        // Send transfer
        bytes32 operationId = router.transferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Should revert when non-adapter tries to update status
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        vm.stopPrank();
    }
}
