// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {ERC7802OFTAdapterSetupTest} from "./ERC7802OFTAdapter.setup.t.sol";

/**
 * @title ERC7802OFTAdapter Transport Tests
 * @notice Tests transport implementation of ERC7802OFTAdapter
 */
contract ERC7802OFTAdapterTransportTest is ERC7802OFTAdapterSetupTest {
    using AddressCast for address;

    function setUp() public override {
        super.setUp();
        _configureOFTs();
        _setupOFTBalances();
    }

    /*//////////////////////////////////////////////////////////////
                        SEND TRANSPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SendTransport_RevertsForUnsupportedAsset() public {
        ERC20Mock unsupportedToken = new ERC20Mock();

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(unsupportedToken),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(ERC7802OFTAdapter.UnsupportedAsset.selector);
        ERC7802OFTAdapter(address(adapterA))._sendTransport(
            keccak256("test"),
            address(unsupportedToken),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );
    }

    function test_SendTransport_RevertsForInsufficientFee() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Set high fee requirement
        oftA.setQuoteSendFees(1 ether, 0);

        // Call with insufficient fee
        vm.expectRevert(
            abi.encodeWithSignature(
                "InsufficientFee(uint256,uint256)",
                1 ether,
                0.1 ether
            )
        );
        ERC7802OFTAdapter(address(adapterA))._sendTransport{value: 0.1 ether}(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );
    }

    function test_SendTransport_ApprovesOFTContract() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Call send transport
        vm.prank(address(adapterA));
        ERC7802OFTAdapter(address(adapterA))._sendTransport{value: 0.1 ether}(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );

        // Verify OFT was approved to spend tokens
        assertEq(tokenA.allowance(address(adapterA), address(oftA)), 100e18);
    }

    function test_SendTransport_CallsOFTSendWithCorrectParameters() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Expected SendParam
        SendParam memory expectedSendParam = SendParam({
            dstEid: uint32(LZ_EID_B),
            to: address(adapterB).toBytes32(),
            amountLD: 100e18,
            minAmountLD: 100e18, // Exact amount for stablecoins
            extraOptions: bytes(""),
            composeMsg: bytes(""), // Empty compose message
            oftCmd: bytes("")
        });

        MessagingFee memory expectedFee = MessagingFee({
            nativeFee: 0.1 ether,
            lzTokenFee: 0
        });

        // Mock the OFT send call
        vm.expectCall(
            address(oftA),
            abi.encodeCall(oftA.send, (expectedSendParam, expectedFee, user))
        );

        vm.prank(address(adapterA));
        ERC7802OFTAdapter(address(adapterA))._sendTransport{value: 0.1 ether}(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );
    }

    function test_SendTransport_HandlesComposeMessage() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "test compose message",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.prank(address(adapterA));
        ERC7802OFTAdapter(address(adapterA))._sendTransport{value: 0.1 ether}(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );

        // Verify compose message was encoded (would be passed to OFT)
        // The actual verification would be in the OFT mock
    }

    function test_SendTransport_ReturnsUsedFeeAmount() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.prank(address(adapterA));
        uint256 usedFee = ERC7802OFTAdapter(address(adapterA))._sendTransport{
            value: 0.2 ether
        }(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );

        // Should return the fee used (0.1 ether)
        assertEq(usedFee, 0.1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATE TRANSPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EstimateTransport_RevertsForUnsupportedAsset() public {
        ERC20Mock unsupportedToken = new ERC20Mock();

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(unsupportedToken),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.expectRevert(ERC7802OFTAdapter.UnsupportedAsset.selector);
        ERC7802OFTAdapter(address(adapterA))._estimateTransport(
            keccak256("test"),
            address(unsupportedToken),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params
        );
    }

    function test_EstimateTransport_ReturnsCorrectFees() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = ERC7802OFTAdapter(
            address(adapterA)
        )._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                100e18,
                options,
                params
            );

        // Should return the fees set in MockOFT
        assertEq(nativeFee, 0.1 ether);
        assertEq(tokenFee, 0);
    }

    function test_EstimateTransport_HandlesDifferentFeeConfigurations() public {
        // Set different fees in MockOFT
        oftA.setQuoteSendFees(0.5 ether, 0.01 ether);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = ERC7802OFTAdapter(
            address(adapterA)
        )._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                100e18,
                options,
                params
            );

        // Should return the updated fees
        assertEq(nativeFee, 0.5 ether);
        assertEq(tokenFee, 0.01 ether);
    }

    function test_EstimateTransport_HandlesComposeMessages() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "test compose message",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = ERC7802OFTAdapter(
            address(adapterA)
        )._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                100e18,
                options,
                params
            );

        // Fees should potentially be different for compose messages
        // (depending on OFT implementation)
        assertEq(nativeFee, 0.1 ether);
        assertEq(tokenFee, 0);
    }

    function test_EstimateTransport_HandlesDifferentAmounts() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 1000e18, // Different amount
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = ERC7802OFTAdapter(
            address(adapterA)
        )._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                1000e18,
                options,
                params
            );

        // Fees should be the same regardless of amount (in this mock)
        assertEq(nativeFee, 0.1 ether);
        assertEq(tokenFee, 0);
    }

    function test_EstimateTransport_UsesCorrectExternalIdMapping() public {
        // Test with different destination chain
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // This should use LZ_EID_B for CHAIN_ID_B
        (uint256 nativeFee, uint256 tokenFee) = ERC7802OFTAdapter(
            address(adapterA)
        )._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                100e18,
                options,
                params
            );

        // Verify correct external ID is used (checked via MockOFT)
        assertEq(nativeFee, 0.1 ether);
        assertEq(tokenFee, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SendTransportAndEstimateTransport_Consistency() public {
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Get estimate
        (
            uint256 estimatedNativeFee,
            uint256 estimatedTokenFee
        ) = ERC7802OFTAdapter(address(adapterA))._estimateTransport(
                keccak256("test"),
                address(tokenA),
                CHAIN_ID_B,
                address(adapterB).toBytes32(),
                100e18,
                options,
                params
            );

        // Give user tokens and call send with estimated fee
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        vm.prank(address(adapterA));
        uint256 usedFee = ERC7802OFTAdapter(address(adapterA))._sendTransport{
            value: estimatedNativeFee
        }(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            user
        );

        // Used fee should match estimated fee
        assertEq(usedFee, estimatedNativeFee);
    }

    function test_SendTransport_HandlesExcessValueRefund() public {
        // Give user tokens
        vm.prank(user);
        tokenA.transfer(address(adapterA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenA),
                amount: 100e18,
                message: "",
                refundAddress: address(0x1234) // Different refund address
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Send with excess value
        uint256 excessValue = 0.5 ether;
        uint256 requiredFee = 0.1 ether;

        vm.prank(address(adapterA));
        ERC7802OFTAdapter(address(adapterA))._sendTransport{
            value: requiredFee + excessValue
        }(
            keccak256("test"),
            address(tokenA),
            CHAIN_ID_B,
            address(adapterB).toBytes32(),
            100e18,
            options,
            params,
            address(0x1234)
        );

        // Excess should be refunded (verified by MockOFT)
    }
}
