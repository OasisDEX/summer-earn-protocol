// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockEndpointV2} from "../mocks/MockEndpointV2.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

contract LayerZeroAdapterTest is Test {
    LayerZeroAdapterTestHelper public adapter;
    MockEndpointV2 public endpoint;
    ERC20Mock public token;

    address adapterOwner = address(this);
    address public bridgeRouter = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

    uint16 public constant CHAIN_ID_ETHEREUM = 1;
    uint16 public constant CHAIN_ID_OPTIMISM = 10;
    uint16 public constant CHAIN_ID_ARBITRUM = 42161;

    uint16 public constant LZ_CHAIN_ID_ETHEREUM = 101;
    uint16 public constant LZ_CHAIN_ID_OPTIMISM = 110;
    uint16 public constant LZ_CHAIN_ID_ARBITRUM = 30200;

    function setUp() public {
        endpoint = new MockEndpointV2();
        token = new ERC20Mock();

        // Create arrays for supported chains and LZ EID mappings
        uint16[] memory supportedChains = new uint16[](3);
        supportedChains[0] = CHAIN_ID_ETHEREUM;
        supportedChains[1] = CHAIN_ID_OPTIMISM;
        supportedChains[2] = CHAIN_ID_ARBITRUM;

        uint32[] memory lzEids = new uint32[](3);
        lzEids[0] = LZ_CHAIN_ID_ETHEREUM;
        lzEids[1] = LZ_CHAIN_ID_OPTIMISM;
        lzEids[2] = LZ_CHAIN_ID_ARBITRUM;

        // Deploy adapter test helper with constructor parameters
        adapter = new LayerZeroAdapterTestHelper(
            address(endpoint),
            bridgeRouter,
            supportedChains,
            lzEids,
            adapterOwner
        );

        // Mint some tokens to the adapter for testing
        token.mint(address(adapter), 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructor() public view {
        // Check that state variables are correctly initialized
        assertEq(address(adapter.endpoint()), address(endpoint));
        assertEq(adapter.bridgeRouter(), bridgeRouter);

        // Check chain ID mappings
        assertEq(adapter.chainToLzEid(CHAIN_ID_ETHEREUM), LZ_CHAIN_ID_ETHEREUM);
        assertEq(adapter.chainToLzEid(CHAIN_ID_OPTIMISM), LZ_CHAIN_ID_OPTIMISM);
        assertEq(adapter.chainToLzEid(CHAIN_ID_ARBITRUM), LZ_CHAIN_ID_ARBITRUM);

        assertEq(adapter.lzEidToChain(LZ_CHAIN_ID_ETHEREUM), CHAIN_ID_ETHEREUM);
        assertEq(adapter.lzEidToChain(LZ_CHAIN_ID_OPTIMISM), CHAIN_ID_OPTIMISM);
        assertEq(adapter.lzEidToChain(LZ_CHAIN_ID_ARBITRUM), CHAIN_ID_ARBITRUM);
    }

    function testConstructorRevertsWithInvalidParams() public {
        uint16[] memory supportedChains = new uint16[](3);
        uint32[] memory lzEids = new uint32[](2); // Different length arrays

        vm.expectRevert(LayerZeroAdapter.InvalidParams.selector);
        new LayerZeroAdapterTestHelper(
            address(endpoint),
            bridgeRouter,
            supportedChains,
            lzEids,
            adapterOwner
        );

        supportedChains = new uint16[](2);
        lzEids = new uint32[](2);

        vm.expectRevert(LayerZeroAdapter.InvalidParams.selector);
        new LayerZeroAdapterTestHelper(
            address(0), // Invalid endpoint address
            bridgeRouter,
            supportedChains,
            lzEids,
            adapterOwner
        );

        vm.expectRevert(LayerZeroAdapter.InvalidParams.selector);
        new LayerZeroAdapterTestHelper(
            address(endpoint),
            address(0), // Invalid bridge router address
            supportedChains,
            lzEids,
            adapterOwner
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferAsset() public {
        // Set up test environment
        vm.startPrank(bridgeRouter);

        uint256 amount = 100 ether;
        uint256 gasLimit = 200000;
        bytes memory adapterParams = "";

        // Call the function (actual implementation would need to be tested)
        /*bytes32 transferId = */ adapter.transferAsset(
            CHAIN_ID_OPTIMISM,
            address(token),
            recipient,
            amount,
            gasLimit,
            adapterParams
        );

        // In a real test, we would verify:
        // 1. The transfer ID is unique and non-zero
        // 2. The token transfer occurred correctly
        // 3. The LayerZero endpoint was called with correct parameters
        // 4. The transfer status was correctly updated

        vm.stopPrank();
    }

    function testTransferAssetRevertsWhenCalledByNonRouter() public {
        vm.startPrank(user); // Not the bridge router

        uint256 amount = 100 ether;
        uint256 gasLimit = 200000;
        bytes memory adapterParams = "";

        vm.expectRevert(LayerZeroAdapter.Unauthorized.selector);
        adapter.transferAsset(
            CHAIN_ID_OPTIMISM,
            address(token),
            recipient,
            amount,
            gasLimit,
            adapterParams
        );

        vm.stopPrank();
    }

    function testEstimateFee() public view {
        uint256 amount = 100 ether;
        uint256 gasLimit = 200000;
        bytes memory adapterParams = "";

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            CHAIN_ID_OPTIMISM,
            address(token),
            amount,
            gasLimit,
            adapterParams
        );

        // In a real test, we would verify the fees are correctly calculated
        // based on LayerZero's fee estimation logic
    }

    function testGetTransferStatus() public {
        bytes32 transferId = bytes32(uint256(1)); // Example transfer ID

        // Set up a test transfer status
        vm.startPrank(bridgeRouter);
        adapter.updateTransferStatus(
            transferId,
            BridgeTypes.TransferStatus.PENDING
        );
        vm.stopPrank();

        // Check the status
        BridgeTypes.TransferStatus status = adapter.getTransferStatus(
            transferId
        );
        assertEq(uint256(status), uint256(BridgeTypes.TransferStatus.PENDING));
    }

    function testGetSupportedChains() public view {
        uint16[] memory supportedChains = adapter.getSupportedChains();

        // In a real test, we would verify the array contains all expected chains
        assertEq(supportedChains.length, 3);
        assertEq(supportedChains[0], CHAIN_ID_ETHEREUM);
        assertEq(supportedChains[1], CHAIN_ID_OPTIMISM);
        assertEq(supportedChains[2], CHAIN_ID_ARBITRUM);
    }

    function testGetSupportedAssets() public view {
        address[] memory supportedAssets = adapter.getSupportedAssets(
            CHAIN_ID_OPTIMISM
        );

        // In a real test, we would verify the array contains all expected assets
        assertEq(supportedAssets.length, 1);
        assertEq(supportedAssets[0], address(token));
    }

    /*//////////////////////////////////////////////////////////////
                         LAYERZERO RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    function testLzReceive() public {
        // Setup test data
        uint32 srcEid = LZ_CHAIN_ID_OPTIMISM; // Source endpoint ID
        bytes memory srcAddress = abi.encodePacked(address(this)); // Source adapter address

        // Create a valid payload with transfer data
        bytes32 transferId = keccak256("test_transfer");
        address asset = address(token);
        uint256 amount = 100 ether;
        bytes memory payload = abi.encode(transferId, asset, amount, recipient);

        // Mock the BridgeRouter to handle receiveAsset calls
        vm.mockCall(
            bridgeRouter,
            abi.encodeWithSelector(IBridgeRouter.receiveAsset.selector),
            abi.encode()
        );

        // Call the lzReceiveTest function with the right parameters
        vm.prank(address(endpoint));
        adapter.lzReceiveTest(srcEid, srcAddress, payload);

        // Verify the transfer was processed correctly
        assertEq(
            uint256(adapter.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );

        // Test failure case by causing the BridgeRouter to revert
        bytes32 failTransferId = keccak256("fail_transfer");
        bytes memory failPayload = abi.encode(
            failTransferId,
            asset,
            amount,
            recipient
        );

        vm.mockCallRevert(
            bridgeRouter,
            abi.encodeWithSelector(IBridgeRouter.receiveAsset.selector),
            "Test failure"
        );

        // Call the lzReceiveTest function with the right parameters
        vm.prank(address(endpoint));
        adapter.lzReceiveTest(srcEid, srcAddress, failPayload);

        // Verify the transfer was marked as failed
        assertEq(
            uint256(adapter.transferStatuses(failTransferId)),
            uint256(BridgeTypes.TransferStatus.FAILED)
        );
    }

    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetLayerZeroChainId() public {
        uint32 lzChainId = adapter.getLayerZeroChainId(CHAIN_ID_OPTIMISM);
        assertEq(lzChainId, LZ_CHAIN_ID_OPTIMISM);

        // Test with unsupported chain
        uint16 unsupportedChain = 999;
        vm.expectRevert(LayerZeroAdapter.UnsupportedChain.selector);
        adapter.getLayerZeroChainId(unsupportedChain);
    }

    function testUpdateTransferStatus() public {
        bytes32 transferId = keccak256("test");

        // Call the exposed function instead of the internal one
        adapter.updateTransferStatus(
            transferId,
            BridgeTypes.TransferStatus.PENDING
        );

        // Verify the transfer status was updated
        assertEq(
            uint256(adapter.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );

        // Update to completed
        adapter.updateTransferStatus(
            transferId,
            BridgeTypes.TransferStatus.COMPLETED
        );

        // Verify the update
        assertEq(
            uint256(adapter.transferStatuses(transferId)),
            uint256(BridgeTypes.TransferStatus.COMPLETED)
        );
    }
}
