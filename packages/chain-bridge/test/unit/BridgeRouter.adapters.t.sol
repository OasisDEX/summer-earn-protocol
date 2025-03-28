// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

contract BridgeRouterAdaptersTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x2);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        vm.startPrank(governor);

        // Deploy contracts
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
        token.mint(governor, 10000e18);
        token.mint(user, 10000e18);

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

        // Get best adapter for lowest cost
        address bestAdapter = router.getBestAdapter(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT
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

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Get the required fee first
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Give the user enough ETH to cover the fee
        vm.deal(user, nativeFee);

        // Send transfer with specified adapter and include the fee
        bytes32 operationId = router.transferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Verify the specified adapter was used
        assertEq(router.operationToAdapter(operationId), address(mockAdapter2));

        vm.stopPrank();
    }

    function testInvalidSpecifiedAdapter() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

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

        // Should revert when using unregistered adapter
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();
    }

    function testAdapterSelectionLimits() public {
        // Register many adapters (more than the limit)
        vm.startPrank(governor);

        // Configure first adapter's fee multiplier
        mockAdapter.setFeeMultiplier(100); // Standard fee

        // Setup second adapter
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        mockAdapter2.setFeeMultiplier(50); // 50% cheaper than the first adapter
        router.registerAdapter(address(mockAdapter2));

        // Register 10 more expensive adapters
        MockAdapter[] memory expensiveAdapters = new MockAdapter[](10);
        for (uint i = 0; i < 10; i++) {
            expensiveAdapters[i] = new MockAdapter(address(router));
            expensiveAdapters[i].setSupportedChain(DEST_CHAIN_ID, true);
            expensiveAdapters[i].setSupportedAsset(
                DEST_CHAIN_ID,
                address(token),
                true
            );
            expensiveAdapters[i].setFeeMultiplier(200 + i); // More expensive
            router.registerAdapter(address(expensiveAdapters[i]));
        }
        vm.stopPrank();

        // Get best adapter - should now find the cheapest adapter
        address bestAdapter = router.getBestAdapter(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT
        );

        // Should be the cheapest adapter (mockAdapter2)
        assertEq(bestAdapter, address(mockAdapter2));
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
