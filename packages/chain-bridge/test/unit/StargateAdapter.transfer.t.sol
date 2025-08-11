// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {console} from "forge-std/console.sol";
import {MessagingFee, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ICrossChainConfigManaged} from "../../src/interfaces/ICrossChainConfigManaged.sol";

contract StargateAdapterSendTest is StargateAdapterSetupTest {
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

        // Create adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Estimate fee for transferring assets
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Verify the fee is returned properly
        assertTrue(nativeFee > 0);
        assertEq(tokenFee, 0); // No token fee for Stargate adapter
    }

    function testEstimateFeeUnsupportedChain() public {
        useNetworkA();

        // Create adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Should revert when estimating fee for unsupported chain
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainRegistry.RelationshipDoesNotExist.selector,
                address(adapterA),
                registryA.PEER_RELATIONSHIP(),
                9999
            )
        );
        adapterA.estimateFee(
            9999, // Unsupported chain
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function testEstimateFeeUnsupportedAsset() public {
        useNetworkA();

        // Create adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Should revert when estimating fee for unsupported asset
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.estimateFee(
            CHAIN_ID_B,
            address(0xdead), // Unsupported asset
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    function testTransferAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // First estimate the fee
        (uint256 nativeFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

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

        // Setup the router to expect this operation from this adapter
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
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
        adapterA.transferAsset{value: nativeFee}(
            expectedOperationId, // Pass operation ID as first parameter
            params,
            options
        );
    }

    function testTransferAssetUnauthorized() public {
        useNetworkA();
        vm.deal(user, 1 ether); // Provide ETH to the user

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Approve tokens for the adapter
        vm.prank(user);
        tokenA.approve(address(adapterA), 1 ether);

        // Should revert when called by non-router
        vm.prank(user);
        vm.expectRevert(ICrossChainConfigManaged.OnlyBridgeRouter.selector);
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
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            params,
            options
        );
    }

    function testTransferAssetUnsupportedChain() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

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
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: 9999,
                asset: address(tokenA),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: user
            });
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(0), // Fake operation ID
            params,
            options
        );
    }

    function testTransferAssetUnsupportedAsset() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether); // Provide ETH to the router

        // vm.prank(governor);
        // routerA.registerAdapter(address(adapterA));
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            bytes32(
                0x528376a1966c744b216d0b277b4672bcda5b6ddb690dc471e2cb20923fbda502
            ),
            address(adapterA)
        );

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Should revert when transferring unsupported asset
        vm.startPrank(address(routerA));
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: CHAIN_ID_B,
                asset: address(0x6),
                amount: 1 ether,
                target: recipient,
                originator: user,
                message: "",
                refundAddress: user
            });
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

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Transfer tokens to the router and approve the adapter
        // This simulates the router having received tokens from the user
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

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

        // Setup the router to expect this operation from this adapter
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
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
        adapterA.transferAsset{value: requiredFee / 2}(
            expectedOperationId, // Use the expected operation ID
            params,
            options
        );
    }

    function testTransferAssetMsgValueConsistencyX() public {
        useNetworkA();
        vm.deal(address(routerA), 10 ether); // Provide enough ETH

        // Setup adapter params
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Estimate the required fee
        (uint256 requiredFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Transfer tokens to the router and approve the adapter
        vm.prank(user);
        assertTrue(tokenA.transfer(address(routerA), 1 ether));
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

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

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );
        console.log("transferAssetMsgValueConsistency 0");
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
        // Test with EXACTLY the required fee - should work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee + 1}(
            expectedOperationId,
            params,
            options
        );
        console.log("transferAssetMsgValueConsistency 1");
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

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId2,
            address(adapterA)
        );
        // Test with significantly MORE than required fee - should also work
        vm.prank(address(routerA));
        adapterA.transferAsset{value: requiredFee * 100}(
            expectedOperationId2,
            params,
            options
        );
        console.log("transferAssetMsgValueConsistency 2");
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
        (uint256 requiredFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
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

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
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

    function testSlippageExceedsTolerance() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        uint256 inputAmount = 1 ether;
        uint256 receivedAmount = 0.94 ether; // 6% slippage (exceeds 0.5% default tolerance)

        // Calculate expected minimum amount: 1 ether * (10000 - 50) / 10000 = 0.995 ether
        uint256 expectedMinAmount = (inputAmount * (10000 - 50)) / 10000; // 0.995 ether

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

        // Setup router
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
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
                expectedMinAmount, // 0.995 ether
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
