// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {StargateAdapter} from "../../../src/adapters/StargateAdapter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BridgeOptionsTestHelper} from "../../helpers/BridgeOptionsTestHelper.sol";
import {TransferHelpers} from "../../helpers/TransferHelpers.t.sol";

/**
 * @title StargateAdapter Protocol Token Fee Tests
 * @notice Tests for protocol token fee payment functionality
 */
contract StargateAdapterProtocolTokenFeeTest is
    StargateAdapterSetupTest,
    TransferHelpers
{
    using BridgeOptionsTestHelper for address;

    ERC20Mock public protocolFeeToken;
    uint256 public constant PROTOCOL_FEE_AMOUNT = 1000e18; // 1000 tokens (matches mock)

    event ProtocolFeeCollected(
        bytes32 indexed operationId,
        address indexed payer,
        address indexed token,
        uint256 tokenFee
    );

    function setUp() public override {
        super.setUp();

        // Deploy a mock protocol fee token
        protocolFeeToken = new ERC20Mock();

        // Configure protocol fee token on adapter
        vm.prank(governor);
        adapterA.setProtocolFeeToken(address(protocolFeeToken));

        // Mint protocol tokens to user
        protocolFeeToken.mint(user, 10000e18);

        // User (keeper) approves adapter to spend protocol tokens
        vm.prank(user);
        protocolFeeToken.approve(address(adapterA), type(uint256).max);
    }

    function testEstimateTransferAssets_WithProtocolTokenFee() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );

        // Should return 0 native fee and the protocol token fee amount
        assertEq(
            nativeFee,
            0,
            "Native fee should be 0 when paying in protocol token"
        );
        assertEq(
            tokenFee,
            PROTOCOL_FEE_AMOUNT,
            "Token fee should match provided amount"
        );
    }

    function testEstimateTransferAssets_InvalidProtocolTokenAmount() public {
        useNetworkA();

        // Create options with wrong protocol token fee amount
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(
                address(adapterA),
                PROTOCOL_FEE_AMOUNT + 1 // Wrong amount
            );

        // Estimation should NOT revert - it should return the correct fees regardless of input
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );

        // Should return the correct fees (not the wrong input amount)
        assertEq(
            tokenFee,
            PROTOCOL_FEE_AMOUNT,
            "Should return correct token fee"
        );
        assertEq(
            nativeFee,
            0,
            "Native fee should be 0 when paying in protocol token"
        );
    }

    function testTransferAsset_WithProtocolTokenFee() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Record initial balances
        uint256 initialUserProtocolBalance = protocolFeeToken.balanceOf(user);
        uint256 initialAdapterProtocolBalance = protocolFeeToken.balanceOf(
            address(adapterA)
        );

        // Execute transfer with protocol token fee
        vm.prank(address(routerA));
        adapterA.transferAsset{value: 0}(
            keccak256("test-operation"),
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );

        // Check protocol token balances
        uint256 finalUserProtocolBalance = protocolFeeToken.balanceOf(user);
        uint256 finalAdapterProtocolBalance = protocolFeeToken.balanceOf(
            address(adapterA)
        );

        assertEq(
            initialUserProtocolBalance - finalUserProtocolBalance,
            PROTOCOL_FEE_AMOUNT,
            "User should have paid protocol fee"
        );
        assertEq(
            finalAdapterProtocolBalance - initialAdapterProtocolBalance,
            PROTOCOL_FEE_AMOUNT,
            "Adapter should have received protocol fee"
        );
    }

    function testTransferAsset_ProtocolTokenFee_EmitsEvent() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        // Transfer tokens to the router and approve the adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        bytes32 operationId = keccak256("test-operation");

        // Expect ProtocolFeeCollected event
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeeCollected(
            operationId,
            user,
            address(protocolFeeToken),
            PROTOCOL_FEE_AMOUNT
        );

        // Execute transfer with protocol token fee
        vm.prank(address(routerA));
        adapterA.transferAsset{value: 0}(
            operationId,
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );
    }

    function testTransferAsset_InsufficientProtocolTokenBalance() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        // Transfer tokens to the router and approve the adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Ensure user has protocol tokens (in case setUp didn't work)
        protocolFeeToken.mint(user, 10000e18);
        vm.prank(user);
        protocolFeeToken.approve(address(adapterA), type(uint256).max);

        // Check user has tokens before transferring them away
        uint256 userBalance = protocolFeeToken.balanceOf(user);
        assertTrue(userBalance > 0, "User should have protocol tokens");

        // Transfer all protocol tokens away from user
        vm.prank(user);
        require(
            protocolFeeToken.transfer(address(0xdead), userBalance),
            "Transfer failed"
        );

        // Should revert due to insufficient balance
        vm.expectRevert();

        vm.prank(address(routerA));
        adapterA.transferAsset{value: 0}(
            keccak256("test-operation"),
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );
    }

    function testTransferAsset_InsufficientProtocolTokenAllowance() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        // Transfer tokens to the router and approve the adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Revoke allowance
        vm.prank(user);
        protocolFeeToken.approve(address(adapterA), 0);

        // Should revert due to insufficient allowance
        vm.expectRevert();

        vm.prank(address(routerA));
        adapterA.transferAsset{value: 0}(
            keccak256("test-operation"),
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );
    }

    function testTransferAsset_ProtocolTokenFee_WithNativeRefund() public {
        useNetworkA();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(adapterA), PROTOCOL_FEE_AMOUNT);

        // Transfer tokens to the router and approve the adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        uint256 refundAmount = 0.1 ether;
        uint256 initialUserBalance = user.balance;

        // Give the test contract some ETH to send
        vm.deal(address(this), refundAmount);

        // Execute transfer with protocol token fee and native refund
        vm.prank(address(routerA));
        vm.deal(address(routerA), refundAmount); // Give router some ETH too
        adapterA.transferAsset{value: refundAmount}(
            keccak256("test-operation"),
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );

        // Check that native refund was processed
        uint256 finalUserBalance = user.balance;
        assertEq(
            finalUserBalance - initialUserBalance,
            refundAmount,
            "User should receive native refund"
        );
    }

    function testEstimateTransferAssets_NoProtocolTokenConfigured() public {
        useNetworkA();

        // Create a new adapter without protocol token configured
        StargateAdapter newAdapter = new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA
        );

        // Configure the new adapter
        vm.startPrank(governor);
        newAdapter.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);
        newAdapter.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);
        newAdapter.addSupportedAsset(address(tokenA), address(stargateA));
        vm.stopPrank();

        // Create a new target adapter for the test
        StargateAdapter newTargetAdapter = new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA
        );

        // Configure the new target adapter
        vm.startPrank(governor);
        newTargetAdapter.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);
        newTargetAdapter.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);
        newTargetAdapter.addSupportedAsset(address(tokenA), address(stargateA));

        // Set up peer relationship in registry
        registryA.registerRelationship(
            address(newAdapter),
            address(newTargetAdapter),
            CHAIN_ID_A,
            CHAIN_ID_B,
            registryA.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(newAdapter), PROTOCOL_FEE_AMOUNT);

        // Should fall back to native fee since no protocol token is configured
        (uint256 nativeFee, uint256 tokenFee) = newAdapter
            .estimateTransferAssets(
                BridgeTypes.ExecuteTransferParams({
                    originator: user,
                    destinationChainId: CHAIN_ID_B,
                    target: recipient,
                    asset: address(tokenA),
                    amount: 1 ether,
                    message: "",
                    refundAddress: user
                }),
                options
            );

        assertTrue(
            nativeFee > 0,
            "Should return native fee when no protocol token configured"
        );
        assertEq(
            tokenFee,
            0,
            "Should return 0 token fee when no protocol token configured"
        );
    }

    function testTransferAsset_NoProtocolTokenConfigured() public {
        useNetworkA();

        // Create a new adapter without protocol token configured
        StargateAdapter newAdapter = new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA
        );

        // Configure the new adapter
        vm.startPrank(governor);
        newAdapter.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);
        newAdapter.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);
        newAdapter.addSupportedAsset(address(tokenA), address(stargateA));
        vm.stopPrank();

        // Create a new target adapter for the test
        StargateAdapter newTargetAdapter = new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA
        );

        // Configure the new target adapter
        vm.startPrank(governor);
        newTargetAdapter.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);
        newTargetAdapter.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);
        newTargetAdapter.addSupportedAsset(address(tokenA), address(stargateA));

        // Set up peer relationship in registry
        registryA.registerRelationship(
            address(newAdapter),
            address(newTargetAdapter),
            CHAIN_ID_A,
            CHAIN_ID_B,
            registryA.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // Create options with protocol token fee
        BridgeTypes.BridgeOptions memory options = BridgeOptionsTestHelper
            .withProtocolTokenFee(address(newAdapter), PROTOCOL_FEE_AMOUNT);

        uint256 nativeFee = 0.1 ether;

        // Transfer tokens to the router and approve the new adapter
        vm.prank(user);
        require(tokenA.transfer(address(routerA), 1 ether), "Transfer failed");
        vm.prank(address(routerA));
        tokenA.approve(address(newAdapter), 1 ether);

        // Give the router some ETH to send (since we're pranking as the router)
        vm.deal(address(routerA), nativeFee);

        // Should fall back to native fee payment
        vm.prank(address(routerA));
        newAdapter.transferAsset{value: nativeFee}(
            keccak256("test-operation"),
            BridgeTypes.ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: user
            }),
            options
        );

        // No protocol token should be transferred
        assertEq(
            protocolFeeToken.balanceOf(user),
            10000e18,
            "User protocol token balance should be unchanged"
        );
    }
}
