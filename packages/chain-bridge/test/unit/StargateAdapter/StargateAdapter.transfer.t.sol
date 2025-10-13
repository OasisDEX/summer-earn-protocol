// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapter} from "../../../src/adapters/StargateAdapter.sol";

import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";

import {ICrossChainRegistry} from "../../../src/interfaces/ICrossChainRegistry.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {console} from "forge-std/console.sol";
import {MessagingFee, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ICrossChainConfigManaged} from "../../../src/interfaces/ICrossChainConfigManaged.sol";
import {TransferHelpers} from "../../helpers/TransferHelpers.t.sol";
import {RejectETH} from "../../mocks/RejectETH.sol";

contract StargateAdapterSendTest is StargateAdapterSetupTest, TransferHelpers {
    // Add event declaration for the event we expect
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    function testEstimateFee() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Estimate fee for transferring assets
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Verify the fee is returned properly
        assertTrue(nativeFee > 0);
        assertEq(tokenFee, 0); // No token fee for Stargate adapter
    }

    function testEstimateFeeUnsupportedChain() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Should revert when estimating fee for unsupported chain
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(adapterA),
                registryA.PEER_RELATIONSHIP(),
                9999
            )
        );
        adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: 9999, // Unsupported chain
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );
    }

    function testEstimateFeeUnsupportedAsset() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Should revert when estimating fee for unsupported asset
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(0xdead), // Unsupported asset
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );
    }

    function testTransferAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // First estimate the fee
        (uint256 nativeFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // Mock a transfer request from the router
        vm.prank(address(routerA));

        // Expect the TransferInitiated event to be emitted (no return value)
        vm.expectEmit(true, true, true, true);
        emit TransferInitiated(
            expectedOperationId,
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            recipient
        );
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                user,
                user
            );
        adapterA.transferAsset{value: nativeFee}(
            expectedOperationId, // Pass operation ID as first parameter
            params,
            options
        );
    }

    function testTransferAssetUnauthorized() public {
        useNetworkA();
        vm.deal(user, 1 ether); // Provide ETH to the user

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Approve tokens for the adapter
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

        // Should revert when called by non-router
        vm.prank(user);
        vm.expectRevert(ICrossChainConfigManaged.OnlyBridgeRouter.selector);
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                user,
                user
            );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            params,
            options
        );
    }

    function testTransferAssetUnsupportedChain() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Should revert when transferring to unsupported chain
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(adapterA),
                registryA.PEER_RELATIONSHIP(),
                9999
            )
        );
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                9999,
                address(tokenA),
                1 ether,
                recipient,
                user,
                user
            );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            params,
            options
        );
    }

    function testTransferAssetUnsupportedAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Should revert when transferring unsupported asset
        vm.startPrank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                CHAIN_ID_B,
                address(0x6),
                1 ether,
                recipient,
                user,
                user
            );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            params,
            options
        );
        vm.stopPrank();
    }

    function testTransferAssetInsufficientFee() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Pre-calculate the operation ID that will be generated
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A, // block.chainid in the test
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // Try to transfer with insufficient fee (half of required)
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientFee.selector,
                requiredFee,
                requiredFee / 2
            )
        );
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                user,
                user
            );
        adapterA.transferAsset{value: requiredFee / 2}(
            expectedOperationId, // Use the expected operation ID
            params,
            options
        );
    }

    function testTransferAssetMsgValueConsistencyX() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether); // Provide enough ETH

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Transfer tokens to the router and approve the adapter
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Pre-calculate the operation ID
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // removed noisy log
        BridgeTypes.ExecuteTransferParams
            memory params = buildExecuteTransferParams(
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                user,
                user
            );
        // Test with EXACTLY the required fee - should work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee + 1}(
            expectedOperationId,
            params,
            options
        );
        // removed noisy log
        // Setup for second transfer - need new tokens, allowance, and operation ID
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Pre-calculate a different operation ID for the second transfer
        bytes32 expectedOperationId2 = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp + 1, // Different timestamp to get different operation ID
                block.number
            )
        );

        // Test with significantly MORE than required fee - should also work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee * 100}(
            expectedOperationId2,
            params,
            options
        );
    }

    function testTransferAssetMsgValueConsistencyEdgeCases() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether);

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Test with 1 wei less than required - should fail
        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // Test with 1 wei less - should fail
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.InsufficientFee.selector,
                requiredFee,
                requiredFee - 1
            )
        );
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: user
            });
        adapterA.transferAsset{value: requiredFee - 1}(
            expectedOperationId,
            params,
            options
        );
    }

    function testTransferAsset_RefundFailure_Reverts() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether);

        BridgeTypes.BridgeOptions memory options = defaultBridgeOptions(
            address(adapterA)
        );

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateTransferAssets(
            BridgeTypes.ExecuteTransferParams({
                originator: address(this),
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1 ether,
                message: "",
                refundAddress: address(this)
            }),
            options
        );

        // Fund router and approve
        fundRouterAndApprove(
            tokenA,
            address(routerA),
            address(adapterA),
            user,
            1 ether
        );

        // Use a refund address that rejects ETH
        RejectETH rejector = new RejectETH();

        bytes32 opId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                recipient,
                block.timestamp,
                block.number
            )
        );

        // Build params with extra msg.value to force a refund attempt (> nativeFee)
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: address(rejector)
            });

        // Expect adapter-specific RefundFailed revert on failed native refund
        vm.prank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(
                StargateAdapter.RefundFailed.selector,
                address(rejector),
                1 wei
            )
        );
        adapterA.transferAsset{value: requiredFee + 1 wei}(
            opId,
            params,
            options
        );
    }

    function testSlippageExceedsTolerance() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        uint256 inputAmount = 1 ether;
        uint256 receivedAmount = 0.94 ether; // 6% slippage (exceeds 0.5% default tolerance)

        // Calculate expected minimum amount using BpsUtils logic: 1 ether - (1 ether * 50 / 10000) = 0.9995 ether
        uint256 expectedMinAmount = 999950000000000000; // 0.9995 ether (actual BpsUtils result)

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Transfer tokens to router and approve
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), inputAmount));

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), inputAmount);

        // Calculate operation ID
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                inputAmount,
                user, // recipient
                block.timestamp,
                block.number
            )
        );

        // Mock the quoteOFT call to return high slippage
        // Create the response structs
        OFTLimit memory limit = OFTLimit({
            minAmountLD: 1,
            maxAmountLD: type(uint256).max
        });

        OFTFeeDetail[] memory feeDetails = new OFTFeeDetail[](1);
        feeDetails[0] = OFTFeeDetail({
            feeAmountLD: -501,
            description: "protocol fee"
        });

        OFTReceipt memory receipt = OFTReceipt({
            amountSentLD: inputAmount,
            amountReceivedLD: receivedAmount // This will trigger slippage check
        });

        // Mock the quoteOFT function to return our custom response
        vm.mockCall(
            address(stargateA),
            abi.encodeWithSignature(
                "quoteOFT((uint32,bytes32,uint256,uint256,bytes,bytes,bytes))"
            ),
            abi.encode(limit, feeDetails, receipt)
        );

        // Expect the SlippageExceedsTolerance revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IBridgeAdapter.SlippageExceedsTolerance.selector,
                expectedMinAmount, // 0.9995 ether
                receivedAmount, // 0.94 ether
                50 // 50 basis points (0.5%)
            )
        );
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: user
            });
        // Execute transfer - should revert due to high slippage
        vm.prank(address(routerA));
        adapterA.transferAsset{value: 0.01 ether}(
            expectedOperationId,
            params,
            options
        );
    }
}
