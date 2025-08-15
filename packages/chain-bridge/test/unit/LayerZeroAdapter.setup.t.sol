// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import {LayerZeroAdapterTestHelper} from "../helpers/LayerZeroAdapterTestHelper.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";

// Base test contract with common setup used by all LayerZero adapter tests
contract LayerZeroAdapterSetupTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    // LayerZero endpoint IDs for TestHelperOz5
    uint32 public aEid = 1;
    uint32 public bEid = 2;

    // Chain A contracts
    LayerZeroAdapterTestHelper public adapterA;
    BridgeRouterTestHelper public routerA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    CrossChainRegistry public registryA;

    // Chain B contracts
    LayerZeroAdapterTestHelper public adapterB;
    BridgeRouterTestHelper public routerB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    CrossChainRegistry public registryB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    address public keeper = governor; // Assuming governor can also act as keeper

    // LayerZero endpoints
    address public lzEndpointA;
    address public lzEndpointB;

    // Chain IDs for testing
    uint16 public constant CHAIN_ID_A = 31337;
    uint16 public constant CHAIN_ID_B = 31338;

    // LayerZero endpoint IDs
    uint32 public constant LZ_EID_A = 1;
    uint32 public constant LZ_EID_B = 2;

    // Network chain IDs for vm.chainId()
    uint256 public constant NETWORK_A_CHAIN_ID = 31337;
    uint256 public constant NETWORK_B_CHAIN_ID = 31338;

    // Default gas limit for testing
    uint256 public constant DEFAULT_GAS_LIMIT = 200000;

    function setUp() public virtual override {
        super.setUp();
        _setupEndpoints();
        _setupChainA();
        _setupChainB();
        _configurePeers();
        useNetworkA();
    }

    function _setupEndpoints() internal {
        // Set up LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);
        lzEndpointA = address(endpoints[aEid]);
        lzEndpointB = address(endpoints[bEid]);

        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");
    }

    function _setupChainA() internal {
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

        // Deploy access manager
        accessManagerA = new ProtocolAccessManager(governor);

        // Deploy registry
        registryA = new CrossChainRegistry(address(accessManagerA), CHAIN_ID_A);

        // Deploy router and configure
        routerA = new BridgeRouterTestHelper(
            address(accessManagerA),
            address(registryA)
        );

        // Initialize bridge configuration in registry
        registryA.initializeBridgeConfiguration(
            address(routerA),
            DEFAULT_GAS_LIMIT
        );

        // Deploy token and adapter with registry
        tokenA = new ERC20Mock();
        adapterA = new LayerZeroAdapterTestHelper(
            lzEndpointA,
            address(registryA),
            address(accessManagerA),
            chains,
            lzEids,
            governor,
            4294965694
        );

        // Final configuration
        routerA.registerAdapter(address(adapterA));
        tokenA.mint(user, 10000e18);

        vm.stopPrank();
    }

    function _setupChainB() internal {
        // Map regular chain IDs to LayerZero EIDs
        uint16[] memory chains = new uint16[](2);
        chains[0] = CHAIN_ID_A;
        chains[1] = CHAIN_ID_B;

        uint32[] memory lzEids = new uint32[](2);
        lzEids[0] = LZ_EID_A;
        lzEids[1] = LZ_EID_B;

        // Deploy contracts on chain B
        useNetworkB();
        vm.startPrank(governor);

        // Deploy access manager
        accessManagerB = new ProtocolAccessManager(governor);

        // Deploy registry
        registryB = new CrossChainRegistry(address(accessManagerB), CHAIN_ID_B);

        // Deploy router and configure
        routerB = new BridgeRouterTestHelper(
            address(accessManagerB),
            address(registryB)
        );

        // Initialize bridge configuration in registry
        registryB.initializeBridgeConfiguration(
            address(routerB),
            DEFAULT_GAS_LIMIT
        );

        // Deploy token and adapter with registry
        tokenB = new ERC20Mock();
        adapterB = new LayerZeroAdapterTestHelper(
            lzEndpointB,
            address(registryB), // Use registry instead of config manager
            address(accessManagerB),
            chains,
            lzEids,
            governor,
            4294965694
        );

        // Final configuration
        routerB.registerAdapter(address(adapterB));
        tokenB.mint(user, 10000e18);

        vm.stopPrank();
    }

    function _configurePeers() internal {
        // Configure Chain A registry
        useNetworkA();
        vm.startPrank(governor);

        // Outgoing: adapterA -> adapterB (for sending messages TO chain B)
        registryA.registerAdapterPeer(
            address(adapterA),
            address(adapterB),
            CHAIN_ID_A,
            CHAIN_ID_B
        );

        // Incoming: adapterB -> adapterA (for receiving messages FROM chain B)
        registryA.registerAdapterPeer(
            address(adapterB), // source adapter (on chain B)
            address(adapterA), // target adapter (on chain A)
            CHAIN_ID_B, // source chain
            CHAIN_ID_A // target chain
        );

        adapterA.setPeer(LZ_EID_B, addressToBytes32(address(adapterB)));
        vm.stopPrank();

        // Configure Chain B registry
        useNetworkB();
        vm.startPrank(governor);

        // Outgoing: adapterB -> adapterA (for sending messages TO chain A)
        registryB.registerAdapterPeer(
            address(adapterB),
            address(adapterA),
            CHAIN_ID_B,
            CHAIN_ID_A
        );

        // Incoming: adapterA -> adapterB (for receiving messages FROM chain A)
        registryB.registerAdapterPeer(
            address(adapterA), // source adapter (on chain A)
            address(adapterB), // target adapter (on chain B)
            CHAIN_ID_A, // source chain
            CHAIN_ID_B // target chain
        );

        adapterB.setPeer(LZ_EID_A, addressToBytes32(address(adapterA)));
        vm.stopPrank();
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

    function testSkipper() public {}
}
