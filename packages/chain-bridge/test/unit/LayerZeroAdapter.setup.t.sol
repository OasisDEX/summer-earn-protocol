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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Base test contract with common setup used by all LayerZero adapter tests
abstract contract LayerZeroAdapterSetupTest is TestHelperOz5 {
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

    function aTest() public {
        useNetworkA();
    }

    // Helper functions for switching networks
    function useNetworkA() public {
        vm.chainId(NETWORK_A_CHAIN_ID);
    }

    function useNetworkB() public {
        vm.chainId(NETWORK_B_CHAIN_ID);
    }

    // Helper function to execute LayerZero messages in tests
    function executeMessage(
        uint32 srcEid,
        address srcAdapter,
        address dstAdapter
    ) internal virtual;
}
