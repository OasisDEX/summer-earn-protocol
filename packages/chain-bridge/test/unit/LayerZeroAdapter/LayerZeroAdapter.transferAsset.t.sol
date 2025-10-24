// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroAdapterSetupTest} from "./LayerZeroAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {ICrossChainConfigManaged} from "../../../src/interfaces/ICrossChainConfigManaged.sol";
import {MockOFT} from "../../mocks/MockOFT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract LayerZeroAdapterTransferAssetTest is LayerZeroAdapterSetupTest {
    MockOFT public mockOFT;
    ERC20Mock public testToken;

    function setUp() public override {
        super.setUp();

        useNetworkA();
        vm.startPrank(governor);

        // Deploy test token and mock OFT
        testToken = new ERC20Mock();
        mockOFT = new MockOFT(
            "Mock OFT",
            "MOFT",
            address(testToken),
            lzEndpointA
        );

        // Set up OFT mapping
        adapterA.setOftForTokenTest(address(testToken), address(mockOFT));

        // Mint tokens to user
        testToken.mint(user, 10000e18);
        testToken.mint(address(routerA), 10000e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        PAYMENT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferAssetRevertsInvalidPaymentMode() public {
        useNetworkA();

        // Set up protocol fee token first
        vm.startPrank(governor);
        adapterA.setProtocolFeeToken(address(testToken));
        vm.stopPrank();

        // Fund router with ETH for the call
        vm.deal(address(routerA), 1 ether);

        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether, // Native value provided
            options: bytes(""),
            payInProtocolToken: true, // Protocol token payment requested
            feeTokenAmount: 1000
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to invalid payment mode (protocol token + native value)
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    function testTransferAssetSuccessNativePayment() public {
        useNetworkA();
        // Fund router with ETH for LayerZero fees
        vm.deal(address(routerA), 1 ether);
        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Approve tokens to adapter
        testToken.approve(address(adapterA), 1000e18);

        // Should succeed with native payment
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    function testTransferAssetSuccessProtocolTokenPayment() public {
        useNetworkA();

        // Set up protocol fee token first
        vm.startPrank(governor);
        adapterA.setProtocolFeeToken(address(testToken));
        vm.stopPrank();

        // Fund router with ETH (even though not used, for consistency)
        vm.deal(address(routerA), 1 ether);

        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0, // No native value
            options: bytes(""),
            payInProtocolToken: true,
            feeTokenAmount: 0 // MockOFT returns 0 fee
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Approve tokens to adapter
        testToken.approve(address(adapterA), 1000e18);

        // Should succeed with protocol token payment
        adapterA.transferAsset{value: 0}(bytes32(uint256(1)), params, options);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferAssetRevertsUnsupportedAsset() public {
        useNetworkA();
        // Fund router with ETH for the call
        vm.deal(address(routerA), 1 ether);
        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params with unsupported asset
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(0xDEAD), // Unsupported asset
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to unsupported asset
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    function testTransferAssetRevertsZeroAmount() public {
        useNetworkA();
        // Fund router with ETH for the call
        vm.deal(address(routerA), 1 ether);
        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params with zero amount
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 0, // Zero amount
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to zero amount
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        OFT PATTERN TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferAssetAdapterPattern() public {
        useNetworkA();
        vm.startPrank(address(routerA));

        // Fund router with ETH for LayerZero fees
        vm.deal(address(routerA), 1 ether);

        // Mock OFT to return different token (adapter pattern)
        MockOFT adapterPatternOFT = new MockOFT(
            "Adapter OFT",
            "AOFT",
            address(testToken),
            lzEndpointA
        );
        adapterA.setOftForTokenTest(
            address(testToken),
            address(adapterPatternOFT)
        );

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Approve tokens to adapter
        testToken.approve(address(adapterA), 1000e18);

        // Should succeed with adapter pattern (asset != oft)
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    function testTransferAssetDirectPattern() public {
        useNetworkA();
        vm.startPrank(address(routerA));

        // Fund router with ETH for LayerZero fees
        vm.deal(address(routerA), 1 ether);

        // Create direct pattern OFT (token == oft)
        MockOFT directPatternOFT = new MockOFT(
            "Direct OFT",
            "DOFT",
            address(0), // Direct pattern: no underlying token
            lzEndpointA
        );
        adapterA.setOftForTokenTest(
            address(directPatternOFT),
            address(directPatternOFT)
        );

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(directPatternOFT),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Mint tokens to router for direct pattern
        directPatternOFT.mint(address(routerA), 1000e18);

        // Approve adapter to pull tokens from router
        directPatternOFT.approve(address(adapterA), 1000e18);

        // Should succeed with direct pattern (asset == oft)
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferAssetRevertsUnauthorizedCaller() public {
        useNetworkA();
        // Fund user with ETH for the call
        vm.deal(user, 1 ether);
        vm.startPrank(user); // User is not the router

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to unauthorized caller
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainConfigManaged.OnlyBridgeRouter.selector
            )
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    function testTransferAssetRevertsUnsupportedDestination() public {
        useNetworkA();
        // Fund router with ETH for the call
        vm.deal(address(routerA), 1 ether);
        vm.startPrank(address(routerA));

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.1 ether,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params with unsupported destination
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: 999, // Unsupported chain
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to unsupported destination
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedDestinationChain.selector,
                uint16(999)
            )
        );
        adapterA.transferAsset{value: 0.1 ether}(
            bytes32(uint256(1)),
            params,
            options
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ESTIMATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testEstimateTransferAssetsSuccess() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(testToken),
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should succeed
        (uint256 nativeFee, uint256 tokenFee) = adapterA.estimateTransferAssets(
            params,
            options
        );

        // Fees should be non-negative
        assertTrue(nativeFee >= 0);
        assertTrue(tokenFee >= 0);
    }

    function testEstimateTransferAssetsRevertsUnsupportedAsset() public {
        useNetworkA();

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes(""),
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        // Prepare transfer params with unsupported asset
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(0xDEAD), // Unsupported asset
                amount: 1000e18,
                message: bytes(""),
                refundAddress: user
            });

        // Should revert due to unsupported asset
        vm.expectRevert(
            abi.encodeWithSelector(IBridgeAdapter.UnsupportedAsset.selector)
        );
        adapterA.estimateTransferAssets(params, options);
    }
}
