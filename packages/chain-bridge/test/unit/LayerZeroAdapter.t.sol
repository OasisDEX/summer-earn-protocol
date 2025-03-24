// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract LayerZeroAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    // LayerZero option type constants
    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    // LayerZero endpoint IDs for TestHelperOz5
    uint32 public aEid = 1;
    uint32 public bEid = 2;

    // Chain A contracts
    LayerZeroAdapter public adapterA;
    BridgeRouter public routerA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;

    // Chain B contracts
    LayerZeroAdapter public adapterB;
    BridgeRouter public routerB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

    // LayerZero endpoints
    address public lzEndpointA;
    address public lzEndpointB;

    // Chain IDs for testing
    uint16 public constant CHAIN_ID_A = 1;
    uint16 public constant CHAIN_ID_B = 10;

    // LayerZero endpoint IDs
    uint32 public constant LZ_EID_A = 1;
    uint32 public constant LZ_EID_B = 2;

    // Network chain IDs for vm.chainId()
    uint256 public constant NETWORK_A_CHAIN_ID = 31337;
    uint256 public constant NETWORK_B_CHAIN_ID = 31338;

    // Add test helper
    LayerZeroAdapterTestHelper public testHelperA;
    LayerZeroAdapterTestHelper public testHelperB;

    function setUp() public override {
        super.setUp();

        // Set up LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);
        lzEndpointA = address(endpoints[aEid]);
        lzEndpointB = address(endpoints[bEid]);

        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        // Map regular chain IDs to LayerZero EIDs
        uint16[] memory chains = new uint16[](2);
        chains[0] = CHAIN_ID_A;
        chains[1] = CHAIN_ID_B;

        uint32[] memory lzEids = new uint32[](2);
        lzEids[0] = LZ_EID_A;
        lzEids[1] = LZ_EID_B;

        // Deploy contracts on chain A
        useNetworkA();
        vm.startPrank(governor);

        accessManagerA = new ProtocolAccessManager(governor);
        routerA = new BridgeRouter(address(accessManagerA));
        tokenA = new ERC20Mock();

        adapterA = new LayerZeroAdapter(
            lzEndpointA,
            address(routerA),
            chains,
            lzEids,
            governor
        );

        // Add test helper
        testHelperA = new LayerZeroAdapterTestHelper(
            lzEndpointA,
            address(routerA),
            chains,
            lzEids,
            governor
        );

        routerA.registerAdapter(address(adapterA));
        tokenA.mint(user, 10000e18);
        tokenA.mint(address(routerA), 10000e18);

        vm.stopPrank();

        // Deploy contracts on chain B
        useNetworkB();
        vm.startPrank(governor);

        accessManagerB = new ProtocolAccessManager(governor);
        routerB = new BridgeRouter(address(accessManagerB));
        tokenB = new ERC20Mock();

        adapterB = new LayerZeroAdapter(
            lzEndpointB,
            address(routerB),
            chains,
            lzEids,
            governor
        );

        // Add test helper
        testHelperB = new LayerZeroAdapterTestHelper(
            lzEndpointB,
            address(routerB),
            chains,
            lzEids,
            governor
        );

        routerB.registerAdapter(address(adapterB));
        tokenB.mint(user, 10000e18);
        tokenB.mint(address(routerB), 10000e18);

        vm.stopPrank();

        // Set up peers between the two adapters
        // First, set up Chain A's adapter to trust Chain B's adapter
        useNetworkA();
        vm.startPrank(governor);
        adapterA.setPeer(LZ_EID_B, addressToBytes32(address(adapterB)));
        vm.stopPrank();

        // Then, set up Chain B's adapter to trust Chain A's adapter
        useNetworkB();
        vm.startPrank(governor);
        adapterB.setPeer(LZ_EID_A, addressToBytes32(address(adapterA)));
        vm.stopPrank();

        // Return to network A for tests to start
        useNetworkA();
    }

    // Helper functions for switching networks
    function useNetworkA() public {
        vm.chainId(NETWORK_A_CHAIN_ID);
    }

    function useNetworkB() public {
        vm.chainId(NETWORK_B_CHAIN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        DIRECT RECEIVE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testReceiveAssetTransferReverts() public {
        // Try to call receiveAssetTransfer directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveAssetTransfer(
            address(tokenA),
            100 ether,
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1)),
            ""
        );
    }

    function testReceiveMessageReverts() public {
        // Try to call receiveMessage directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveMessage(
            bytes("test message"),
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1))
        );
    }

    function testReceiveStateReadReverts() public {
        // Try to call receiveStateRead directly, which should revert
        vm.expectRevert(LayerZeroAdapter.UseLayerZeroMessaging.selector);
        adapterA.receiveStateRead(
            bytes("test data"),
            recipient,
            CHAIN_ID_B,
            bytes32(uint256(1))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        uint16[] memory supportedChains = adapterA.getSupportedChains();
        assertEq(supportedChains.length, 2);
        assertEq(supportedChains[0], CHAIN_ID_A);
        assertEq(supportedChains[1], CHAIN_ID_B);
    }

    function testSupportsChain() public view {
        assertTrue(adapterA.supportsChain(CHAIN_ID_A));
        assertTrue(adapterA.supportsChain(CHAIN_ID_B));
        assertFalse(adapterA.supportsChain(2)); // Arbitrary unsupported chain
    }

    function testSupportsAsset() public view {
        // Currently all assets are supported on supported chains
        assertTrue(adapterA.supportsAsset(CHAIN_ID_A, address(tokenA)));
        assertTrue(adapterA.supportsAsset(CHAIN_ID_B, address(tokenB)));
        assertFalse(adapterA.supportsAsset(2, address(tokenA))); // Unsupported chain
    }

    function testGetAdapterType() public view {
        assertEq(adapterA.getAdapterType(), 1); // 1 for LayerZero
    }

    // Update test for UnsupportedMessageType error since type 5 is now COMPOSE
    function testUnsupportedMessageType() public {
        // Create a message with an unsupported type (9 - which doesn't exist)
        bytes memory invalidPayload = abi.encodePacked(
            uint16(9),
            bytes("test payload")
        );

        // Create origin data
        Origin memory origin = Origin({
            srcEid: LZ_EID_B, // Source is chain B
            sender: addressToBytes32(address(testHelperB)),
            nonce: 1
        });

        // Expect revert with UnsupportedMessageType
        vm.expectRevert(LayerZeroAdapter.UnsupportedMessageType.selector);

        // Call the test helper's lzReceiveTest function with the invalid payload
        testHelperA.lzReceiveTest(
            origin,
            bytes32(uint256(1)), // requestId
            invalidPayload,
            address(testHelperB), // sender
            bytes("") // extraData
        );
    }

    function testGetRequiredFeeWithMinGasLimit() public {
        useNetworkA();
        vm.startPrank(governor);

        // Set minimum gas limit for TRANSFER with a high value
        adapterA.setMinGasLimit(adapterA.TRANSFER(), 1000000);

        // Create a simple payload for testing
        bytes memory payload = abi.encodePacked(
            uint16(adapterA.TRANSFER()),
            bytes("test payload")
        );

        // Get required fee
        uint256 requiredFee = adapterA.getRequiredFee(
            LZ_EID_B,
            adapterA.TRANSFER(),
            payload
        );

        // Fee should be non-zero
        assertTrue(requiredFee > 0);

        vm.stopPrank();
    }

    function testSetMinGasLimit() public {
        useNetworkA();

        // Initial minimum gas limit for TRANSFER should be 500000 (set in constructor)
        uint128 initialMinGas = adapterA.minGasLimits(adapterA.TRANSFER());
        assertEq(initialMinGas, 500000);

        // Only the governor should be able to set minimum gas limits
        vm.prank(user);
        vm.expectRevert(); // Should revert when called by non-governor
        adapterA.setMinGasLimit(adapterA.TRANSFER(), 1000000);

        // Governor can set minimum gas limits
        vm.prank(governor);
        adapterA.setMinGasLimit(adapterA.TRANSFER(), 1000000);

        // Verify the minimum gas limit was updated
        uint128 newMinGas = adapterA.minGasLimits(adapterA.TRANSFER());
        assertEq(newMinGas, 1000000);
    }

    function testMinGasLimitEnforcement() public {
        useNetworkA();
        vm.startPrank(governor);

        // Set a high minimum gas limit for TRANSFER
        uint128 minGasLimit = 1000000;
        adapterA.setMinGasLimit(adapterA.TRANSFER(), minGasLimit);

        // Prepare a transfer with a lower gas limit than the minimum
        uint256 amount = 100 ether;

        // Create adapter params with a lower gas limit
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000, // Lower than our minimum
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Get the fee estimate (this calls _prepareOptions internally)
        (uint256 nativeFee, , ) = routerA.quote(
            CHAIN_ID_B,
            address(tokenA),
            amount,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                adapterParams: adapterParams
            })
        );

        // The fee should reflect the higher minimum gas limit
        assertTrue(nativeFee > 0);

        // Now create adapter params with a higher gas limit than the minimum
        BridgeTypes.AdapterParams memory higherParams = BridgeTypes
            .AdapterParams({
                gasLimit: 1500000, // Higher than our minimum
                msgValue: 0,
                calldataSize: 0,
                options: bytes("")
            });

        // Get the fee estimate for the higher gas limit
        (uint256 higherFee, , ) = routerA.quote(
            CHAIN_ID_B,
            address(tokenA),
            amount,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(adapterA),
                adapterParams: higherParams
            })
        );

        // Higher gas limit should result in a higher fee
        assertTrue(higherFee > nativeFee);

        vm.stopPrank();
    }

    function testComposeActions() public {
        useNetworkA();
        vm.startPrank(user);

        // Create sample actions to compose
        bytes[] memory actions = new bytes[](2);
        actions[0] = abi.encodeWithSignature(
            "sampleAction1(address,uint256)",
            recipient,
            100
        );
        actions[1] = abi.encodeWithSignature(
            "sampleAction2(address,bool)",
            recipient,
            true
        );

        // Create bridge options with a gas limit
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 800000,
                calldataSize: 0,
                msgValue: 0,
                options: bytes("") // No need for complex options now
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            adapterParams: adapterParams
        });

        // Estimate the fee
        (uint256 nativeFee, , ) = routerA.quote(
            CHAIN_ID_B,
            address(0),
            0,
            options
        );

        // Initiate composed actions with the required fee
        bytes32 requestId = routerA.composeActions{value: nativeFee}(
            CHAIN_ID_B,
            actions,
            options
        );

        // Verify the request was registered
        assertEq(
            uint256(routerA.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );
        assertEq(routerA.transferToAdapter(requestId), address(adapterA));

        vm.stopPrank();
    }
}
