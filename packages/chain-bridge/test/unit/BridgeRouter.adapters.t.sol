// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";

contract BridgeRouterAdapterTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;

    address public admin = address(0x1);
    address public user = address(0x2);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        router = new BridgeRouter();
        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(admin, 10000e18);
        token.mint(user, 10000e18);

        vm.stopPrank();
    }

    // ---- ADAPTER MANAGEMENT TESTS ----

    function testRegisterAdapter() public {
        vm.startPrank(admin);

        // Register second adapter
        assertFalse(router.adapters(address(mockAdapter2)));
        router.registerAdapter(address(mockAdapter2));
        assertTrue(router.adapters(address(mockAdapter2)));

        vm.stopPrank();
    }

    function testRegisterAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to register adapter
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.registerAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testRegisterDuplicateAdapter() public {
        vm.startPrank(admin);

        // Should revert when registering same adapter twice
        vm.expectRevert(BridgeRouter.AdapterAlreadyRegistered.selector);
        router.registerAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveAdapter() public {
        vm.startPrank(admin);

        // Remove adapter
        assertTrue(router.adapters(address(mockAdapter)));
        router.removeAdapter(address(mockAdapter));
        assertFalse(router.adapters(address(mockAdapter)));

        vm.stopPrank();
    }

    function testRemoveAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to remove adapter
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.removeAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveNonExistentAdapter() public {
        vm.startPrank(admin);

        // Should revert when removing non-existent adapter
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.removeAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testGetAdapters() public {
        vm.startPrank(admin);

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
        vm.startPrank(admin);
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        mockAdapter2.setFeeMultiplier(150); // 50% more expensive
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        // Get best adapter for lowest cost
        address bestAdapter = router.getBestAdapter(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            0 // Lowest cost preference
        );

        // Should select the cheaper adapter
        assertEq(bestAdapter, address(mockAdapter));
    }

    function testSpecifiedAdapter() public {
        vm.startPrank(admin);
        // Register second adapter
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options with specified adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(mockAdapter2)
        });

        // Send transfer with specified adapter
        bytes32 transferId = router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Verify the specified adapter was used
        assertEq(router.transferToAdapter(transferId), address(mockAdapter2));

        vm.stopPrank();
    }

    function testInvalidSpecifiedAdapter() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options with invalid adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0x123) // Unregistered adapter
        });

        // Should revert when using unregistered adapter
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
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
        vm.startPrank(admin);

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

        // Get best adapter - even with iteration limits, should still find mockAdapter2
        address bestAdapter = router.getBestAdapter(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            0 // Lowest cost preference
        );

        // Should select the cheaper adapter (mockAdapter2)
        assertEq(bestAdapter, address(mockAdapter2));
    }

    // ---- FEE ESTIMATION TESTS ----

    function testQuote() public {
        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Get quote
        (uint256 nativeFee, uint256 tokenFee, address selectedAdapter) = router
            .quote(DEST_CHAIN_ID, address(token), TRANSFER_AMOUNT, options);

        // Verify quote
        assertEq(selectedAdapter, address(mockAdapter));
        assertTrue(nativeFee > 0);
    }

    function testQuoteNoSuitableAdapter() public {
        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Should revert for unsupported chain
        vm.expectRevert(BridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            options
        );
    }
}
