// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";

import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

/**
 * @title BaseERC7802Adapter Setup Test
 * @notice Common setup and fixtures for BaseERC7802Adapter tests
 * @dev This is an abstract contract - concrete implementations should inherit and implement _deployAdapter
 */
abstract contract BaseERC7802AdapterSetupTest is TestHelperOz5 {
    using AddressCast for address;

    // LayerZero endpoint IDs for TestHelperOz5
    uint32 public aEid = 1;
    uint32 public bEid = 2;

    // Chain A contracts
    BaseERC7802Adapter public adapterA;
    BridgeRouterTestHelper public routerA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    CrossChainRegistry public registryA;

    // Chain B contracts
    BaseERC7802Adapter public adapterB;
    BridgeRouterTestHelper public routerB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    CrossChainRegistry public registryB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    address public keeper = governor;

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
        registryA = new CrossChainRegistry(address(accessManagerA));

        // Deploy router and configure
        routerA = new BridgeRouterTestHelper(
            address(accessManagerA),
            address(registryA)
        );

        // Initialize bridge configuration in registry
        registryA.setBridgeRouter(address(routerA));

        // Deploy token and adapter with registry
        tokenA = new ERC20Mock();
        adapterA = _deployAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA,
            chains,
            lzEids
        );

        // Enable asset support for testing
        adapterA.setAssetSupport(address(tokenA), true);

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
        registryB = new CrossChainRegistry(address(accessManagerB));

        // Deploy router and configure
        routerB = new BridgeRouterTestHelper(
            address(accessManagerB),
            address(registryB)
        );

        // Initialize bridge configuration in registry
        registryB.setBridgeRouter(address(routerB));

        // Deploy token and adapter with registry
        tokenB = new ERC20Mock();
        adapterB = _deployAdapter(
            address(registryB),
            address(accessManagerB),
            lzEndpointB,
            chains,
            lzEids
        );

        // Enable asset support for testing
        adapterB.setAssetSupport(address(tokenB), true);

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
        try
            registryA.registerAdapterPeerPair(
                address(adapterA),
                address(adapterB),
                CHAIN_ID_A,
                CHAIN_ID_B
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        // Incoming: adapterB -> adapterA (for receiving messages FROM chain B)
        try
            registryA.registerAdapterPeerPair(
                address(adapterB), // source adapter (on chain B)
                address(adapterA), // target adapter (on chain A)
                CHAIN_ID_B, // source chain
                CHAIN_ID_A // target chain
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        // Configure external ID mappings
        adapterA.mapExternalId(CHAIN_ID_A, LZ_EID_A);
        adapterA.mapExternalId(CHAIN_ID_B, LZ_EID_B);

        vm.stopPrank();

        // Configure Chain B registry
        useNetworkB();
        vm.startPrank(governor);

        // Outgoing: adapterB -> adapterA (for sending messages TO chain A)
        try
            registryB.registerAdapterPeerPair(
                address(adapterB),
                address(adapterA),
                CHAIN_ID_B,
                CHAIN_ID_A
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        // Incoming: adapterA -> adapterB (for receiving messages FROM chain A)
        try
            registryB.registerAdapterPeerPair(
                address(adapterA), // source adapter (on chain A)
                address(adapterB), // target adapter (on chain B)
                CHAIN_ID_A, // source chain
                CHAIN_ID_B // target chain
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        // Configure external ID mappings
        adapterB.mapExternalId(CHAIN_ID_A, LZ_EID_A);
        adapterB.mapExternalId(CHAIN_ID_B, LZ_EID_B);

        vm.stopPrank();
    }

    /**
     * @notice Deploy the concrete adapter implementation
     * @dev Must be implemented by concrete test contracts
     */
    function _deployAdapter(
        address registry,
        address accessManager,
        address lzEndpoint,
        uint16[] memory chains,
        uint32[] memory lzEids
    ) internal virtual returns (BaseERC7802Adapter);

    // Helper functions for switching networks
    function useNetworkA() public {
        vm.chainId(NETWORK_A_CHAIN_ID);
    }

    function useNetworkB() public {
        vm.chainId(NETWORK_B_CHAIN_ID);
    }

    function testSkipper() public {}
}
