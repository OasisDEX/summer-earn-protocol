// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapter} from "../../../src/adapters/StargateAdapter.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {MockHarborCommand} from "../../mocks/MockHarborCommand.sol";
import {MockStargateV2Pool} from "../../mocks/MockStargateV2.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockHarborCommand} from "../../mocks/MockHarborCommand.sol";
import {CrossChainRegistry} from "../../../src/contracts/CrossChainRegistry.sol";

// Base test contract with common setup used by all Stargate adapter tests
contract StargateAdapterSetupTest is TestHelperOz5 {
    // LayerZero endpoint IDs for TestHelperOz5
    uint32 public aEid = 1;
    uint32 public bEid = 2;

    // Chain A contracts
    StargateAdapter public adapterA;
    BridgeRouterTestHelper public routerA;
    CrossChainRegistry public registryA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    MockStargateV2Pool public stargateA;

    // Chain B contracts
    StargateAdapter public adapterB;
    BridgeRouterTestHelper public routerB;
    CrossChainRegistry public registryB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    MockStargateV2Pool public stargateB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    // address public keeper = governor; // Unused currently; keep commented for future use

    // Chain IDs for testing
    uint16 public constant CHAIN_ID_A = 31337;
    uint16 public constant CHAIN_ID_B = 31338;

    // Network chain IDs for vm.chainId()
    uint256 public constant NETWORK_A_CHAIN_ID = 31337;
    uint256 public constant NETWORK_B_CHAIN_ID = 31338;

    // LayerZero endpoint IDs
    uint32 public constant ENDPOINT_ID_A = 30101;
    uint32 public constant ENDPOINT_ID_B = 30102;

    // LayerZero endpoints
    address public lzEndpointA;
    address public lzEndpointB;

    // Add harbor command mocks
    MockHarborCommand public harborCommandA;
    MockHarborCommand public harborCommandB;

    function setUp() public virtual override {
        super.setUp();

        // Set up LayerZero endpoints using TestHelperOz5
        setUpEndpoints(2, LibraryType.UltraLightNode);
        lzEndpointA = address(endpoints[aEid]);
        lzEndpointB = address(endpoints[bEid]);

        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        // Deploy contracts on chain A
        useNetworkA();
        vm.startPrank(governor);

        // Initialize tokens and Stargate mocks for chain A
        tokenA = new ERC20Mock();
        stargateA = new MockStargateV2Pool(address(tokenA));

        accessManagerA = new ProtocolAccessManager(governor);
        registryA = new CrossChainRegistry(address(accessManagerA));
        harborCommandA = new MockHarborCommand();
        routerA = new BridgeRouterTestHelper(
            address(accessManagerA),
            address(registryA)
        );

        registryA.setBridgeRouter(address(routerA));

        // Deploy adapter with registry instead of config manager
        adapterA = new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            lzEndpointA
        );

        // Set endpoint ID instead of addSupportedChain
        adapterA.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);
        adapterA.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);

        adapterA.addSupportedAsset(address(tokenA), address(stargateA));

        routerA.registerAdapter(address(adapterA));
        tokenA.mint(user, 10000e18);

        vm.stopPrank();

        // Deploy contracts on chain B
        useNetworkB();
        vm.startPrank(governor);

        // Initialize tokens and Stargate mocks for chain B
        tokenB = new ERC20Mock();
        stargateB = new MockStargateV2Pool(address(tokenB));

        accessManagerB = new ProtocolAccessManager(governor);
        registryB = new CrossChainRegistry(address(accessManagerB));
        harborCommandB = new MockHarborCommand();
        routerB = new BridgeRouterTestHelper(
            address(accessManagerB),
            address(registryB)
        );

        registryB.setBridgeRouter(address(routerB));

        // Deploy adapter with registry instead of config manager
        adapterB = new StargateAdapter(
            address(registryB),
            address(accessManagerB),
            lzEndpointB
        );

        // Set endpoint ID instead of addSupportedChain
        adapterB.mapExternalId(CHAIN_ID_B, ENDPOINT_ID_B);
        adapterB.mapExternalId(CHAIN_ID_A, ENDPOINT_ID_A);

        // Register the cross-chain relationship between adapters ON CHAIN B
        try
            registryB.registerAdapterPeerPair(
                address(adapterA), // sourceAdapter (on Chain A)
                address(adapterB), // targetAdapter (on Chain B)
                CHAIN_ID_A, // sourceChainId
                CHAIN_ID_B // targetChainId
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        try
            registryB.registerAdapterPeerPair(
                address(adapterB), // sourceAdapter (on Chain B)
                address(adapterA), // targetAdapter (on Chain A)
                CHAIN_ID_B, // sourceChainId
                CHAIN_ID_A // targetChainId
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        adapterB.addSupportedAsset(address(tokenB), address(stargateB));

        routerB.registerAdapter(address(adapterB));
        tokenB.mint(user, 10000e18);

        vm.stopPrank();

        // Back to Chain A to register BOTH relationships
        useNetworkA();
        vm.startPrank(governor);
        try
            registryA.registerAdapterPeerPair(
                address(adapterA), // sourceAdapter (on Chain A)
                address(adapterB), // targetAdapter (on Chain B)
                CHAIN_ID_A, // sourceChainId
                CHAIN_ID_B // targetChainId
            )
        {} catch {
            // Relationship already exists, ignore the error
        }

        try
            registryA.registerAdapterPeerPair(
                address(adapterB), // sourceAdapter (on Chain B)
                address(adapterA), // targetAdapter (on Chain A)
                CHAIN_ID_B, // sourceChainId
                CHAIN_ID_A // targetChainId
            )
        {} catch {
            // Relationship already exists, ignore the error
        }
        vm.stopPrank();

        vm.label(address(tokenA), "Token A");
        vm.label(address(tokenB), "Token B");
        vm.label(address(stargateA), "Stargate A");
        vm.label(address(stargateB), "Stargate B");
        vm.label(address(adapterA), "Adapter A");
        vm.label(address(adapterB), "Adapter B");
        vm.label(address(routerA), "Router A");
        vm.label(address(routerB), "Router B");
        vm.label(address(registryA), "Registry A");
        vm.label(address(registryB), "Registry B");
        vm.label(address(harborCommandA), "Harbor Command A");
        vm.label(address(harborCommandB), "Harbor Command B");
        vm.label(address(accessManagerA), "Access Manager A");
        vm.label(address(accessManagerB), "Access Manager B");
    }

    function testConstructor_RevertWhenZeroEndpoint() public {
        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        // lzEndpoint zero should revert in adapter constructor
        new StargateAdapter(
            address(registryA),
            address(accessManagerA),
            address(0)
        );
    }

    // Helper functions for switching networks
    function useNetworkA() public {
        vm.chainId(NETWORK_A_CHAIN_ID);
    }

    function useNetworkB() public {
        vm.chainId(NETWORK_B_CHAIN_ID);
    }
}
