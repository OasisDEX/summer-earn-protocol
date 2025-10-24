// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SuperchainAdapterSetupTest} from "./SuperchainAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {ICrossChainConfigManaged} from "../../../src/interfaces/ICrossChainConfigManaged.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SuperchainAdapterTransferTest is SuperchainAdapterSetupTest {
    // Add event declaration for the event we expect
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    event ERC20Sent(
        address indexed token,
        uint32 indexed destinationChainId,
        address indexed recipient,
        uint256 amount
    );

    function testTransferAsset_SuccessfulTransfer() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Expect TransferInitiated event
        vm.expectEmit(true, true, true, true);
        emit TransferInitiated(
            operationId,
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient
        );

        // Expect ERC20Sent event from SuperchainTokenBridge
        vm.expectEmit(true, true, true, true);
        emit ERC20Sent(
            address(tokenA),
            EXTERNAL_ID_B,
            address(adapterB), // destination adapter
            transferAmount
        );

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset(operationId, params, options);

        // Verify token was transferred from router to adapter
        assertEq(tokenA.balanceOf(address(adapterA)), transferAmount);
        assertEq(tokenA.balanceOf(address(routerA)), 0);

        // Verify sendMessage was called on L2ToL2CrossDomainMessenger
        assertEq(l2ToL2MessengerA.lastChainId(), EXTERNAL_ID_B);
        assertEq(l2ToL2MessengerA.lastTarget(), address(adapterB));
        assertTrue(l2ToL2MessengerA.lastMessage().length > 0);
    }

    function testTransferAsset_RevertWhenUnauthorizedCaller() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Should revert when called by non-router
        vm.prank(user);
        vm.expectRevert(ICrossChainConfigManaged.OnlyBridgeRouter.selector);
        adapterA.transferAsset(operationId, params, options);
    }

    function testTransferAsset_RevertWhenUnsupportedAsset() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");
        address unsupportedToken = address(0x999);

        // Create unsupported token
        ERC20Mock unsupportedTokenMock = new ERC20Mock();
        unsupportedTokenMock.mint(user, transferAmount);

        // Fund router and approve adapter
        vm.prank(user);
        unsupportedTokenMock.transfer(address(routerA), transferAmount);
        vm.prank(address(routerA));
        unsupportedTokenMock.approve(address(adapterA), transferAmount);

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(unsupportedTokenMock),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Should revert when transferring unsupported asset
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.transferAsset(operationId, params, options);
    }

    function testTransferAsset_RevertWhenUnsupportedChain() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            9999, // Unsupported chain
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Should revert when transferring to unsupported chain
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedDestinationChain.selector,
                9999
            )
        );
        adapterA.transferAsset(operationId, params, options);
    }

    function testTransferAsset_RevertWhenZeroAmount() public {
        useChainA();

        bytes32 operationId = keccak256("test-operation");

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            0, // Zero amount
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Should revert when transferring zero amount
        vm.prank(address(routerA));
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidAmount.selector);
        adapterA.transferAsset(operationId, params, options);
    }

    function testTransferAsset_VerifySuperchainBridgeCall() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset(operationId, params, options);

        // Verify SuperchainTokenBridge.sendERC20 was called with correct parameters
        // The event emission in the test above already verifies this
        // Additional verification: check that the adapter's token balance is correct
        assertEq(tokenA.balanceOf(address(adapterA)), transferAmount);
    }

    function testTransferAsset_VerifyL2ToL2MessengerCall() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId = keccak256("test-operation");

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset(operationId, params, options);

        // Verify L2ToL2CrossDomainMessenger.sendMessage was called with correct parameters
        assertEq(l2ToL2MessengerA.lastChainId(), EXTERNAL_ID_B);
        assertEq(l2ToL2MessengerA.lastTarget(), address(adapterB));
        assertTrue(l2ToL2MessengerA.lastMessage().length > 0);
        assertTrue(l2ToL2MessengerA.lastMessageHash() != bytes32(0));
    }

    function testTransferAsset_MultipleTransfers() public {
        useChainA();

        uint256 transferAmount = 1000e18;
        bytes32 operationId1 = keccak256("test-operation-1");
        bytes32 operationId2 = keccak256("test-operation-2");

        // First transfer
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params1 = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        vm.prank(address(routerA));
        adapterA.transferAsset(operationId1, params1, options);

        // Second transfer
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            transferAmount
        );

        BridgeTypes.ExecuteTransferParams memory params2 = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            transferAmount,
            recipient,
            user,
            user
        );

        vm.prank(address(routerA));
        adapterA.transferAsset(operationId2, params2, options);

        // Verify both transfers completed
        assertEq(tokenA.balanceOf(address(adapterA)), transferAmount * 2);
        assertEq(tokenA.balanceOf(address(routerA)), 0);
    }

    function testTransferAsset_LargeAmount() public {
        useChainA();

        uint256 largeAmount = 1000000e18; // 1M tokens
        bytes32 operationId = keccak256("test-operation");

        // Mint large amount to user
        tokenA.mint(user, largeAmount);

        // Fund router and approve adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            largeAmount
        );

        BridgeTypes.ExecuteTransferParams memory params = createTransferParams(
            CHAIN_ID_B,
            address(tokenA),
            largeAmount,
            recipient,
            user,
            user
        );

        BridgeTypes.BridgeOptions memory options = createBridgeOptions(
            address(adapterA)
        );

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset(operationId, params, options);

        // Verify large transfer completed
        assertEq(tokenA.balanceOf(address(adapterA)), largeAmount);
        assertEq(tokenA.balanceOf(address(routerA)), 0);
    }
}
