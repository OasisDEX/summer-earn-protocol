// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockStargateRouter} from "../mocks/MockStargateRouter.sol";

// Base test contract with common setup used by all Stargate adapter tests
contract StargateAdapterSetupTest is Test {
    // Chain A contracts
    StargateAdapter public adapterA;
    BridgeRouterTestHelper public routerA;
    BridgeQueue public bridgeQueueA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    MockStargateRouter public stargateRouterA;

    // Chain B contracts
    StargateAdapter public adapterB;
    BridgeRouterTestHelper public routerB;
    BridgeQueue public bridgeQueueB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    MockStargateRouter public stargateRouterB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    address public keeper = governor; // Assuming governor can also act as keeper

    // Chain IDs for testing
    uint16 public constant CHAIN_ID_A = 31337;
    uint16 public constant CHAIN_ID_B = 31338;

    // Network chain IDs for vm.chainId()
    uint256 public constant NETWORK_A_CHAIN_ID = 31337;
    uint256 public constant NETWORK_B_CHAIN_ID = 31338;

    // Stargate pool IDs
    uint256 public constant POOL_ID_A = 1;
    uint256 public constant POOL_ID_B = 2;

    function setUp() public virtual {
        // Deploy contracts on chain A
        useNetworkA();
        vm.startPrank(governor);

        accessManagerA = new ProtocolAccessManager(governor);
        bridgeQueueA = new BridgeQueue(
            address(accessManagerA),
            address(0), // Router set later
            governor // Use governor as queue manager
        );
        routerA = new BridgeRouterTestHelper(
            address(accessManagerA),
            address(bridgeQueueA), // Pass queue address
            new uint16[](0),
            new address[](0)
        );
        bridgeQueueA.setBridgeRouter(address(routerA));
        tokenA = new ERC20Mock();
        stargateRouterA = new MockStargateRouter();

        adapterA = new StargateAdapter(
            address(stargateRouterA),
            address(routerA),
            governor
        );

        adapterA.addSupportedChain(CHAIN_ID_A, CHAIN_ID_A); // Map local chain ID to Stargate chain ID
        adapterA.addSupportedChain(CHAIN_ID_B, CHAIN_ID_B); // Map remote chain ID to Stargate chain ID

        adapterA.addSupportedAsset(CHAIN_ID_A, address(tokenA), POOL_ID_A);
        adapterA.addSupportedAsset(CHAIN_ID_B, address(tokenA), POOL_ID_B); // Same token but different pool ID on remote chain

        routerA.registerAdapter(address(adapterA));
        tokenA.mint(user, 10000e18);
        tokenA.mint(address(bridgeQueueA), 10000e18); // Mint to queue for transfers

        vm.stopPrank();

        // Deploy contracts on chain B
        useNetworkB();
        vm.startPrank(governor);

        accessManagerB = new ProtocolAccessManager(governor);
        bridgeQueueB = new BridgeQueue(
            address(accessManagerB),
            address(0), // Router set later
            governor // Use governor as queue manager
        );
        routerB = new BridgeRouterTestHelper(
            address(accessManagerB),
            address(bridgeQueueB), // Pass queue address
            new uint16[](0),
            new address[](0)
        );
        bridgeQueueB.setBridgeRouter(address(routerB));
        tokenB = new ERC20Mock();
        stargateRouterB = new MockStargateRouter();

        adapterB = new StargateAdapter(
            address(stargateRouterB),
            address(routerB),
            governor
        );

        adapterB.addSupportedChain(CHAIN_ID_B, CHAIN_ID_B); // Map local chain ID to Stargate chain ID
        adapterB.addSupportedChain(CHAIN_ID_A, CHAIN_ID_A); // Map remote chain ID to Stargate chain ID

        adapterB.addSupportedAsset(CHAIN_ID_B, address(tokenB), POOL_ID_B);
        adapterB.addSupportedAsset(CHAIN_ID_A, address(tokenB), POOL_ID_A); // Same token but different pool ID on remote chain

        routerB.registerAdapter(address(adapterB));
        tokenB.mint(user, 10000e18);
        tokenB.mint(address(bridgeQueueB), 10000e18); // Mint to queue for transfers

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
}
