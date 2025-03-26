// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {IStargateRouter} from "../../src/interfaces/IStargateRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockStargateRouter} from "../mocks/MockStargateRouter.sol";

// Base test contract with common setup used by all Stargate adapter tests
contract StargateAdapterSetupTest is Test {
    // Chain A contracts
    StargateAdapter public adapterA;
    BridgeRouterTestHelper public routerA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    MockStargateRouter public stargateRouterA;

    // Chain B contracts
    StargateAdapter public adapterB;
    BridgeRouterTestHelper public routerB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    MockStargateRouter public stargateRouterB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);

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
        routerA = new BridgeRouterTestHelper(address(accessManagerA));
        tokenA = new ERC20Mock();
        stargateRouterA = new MockStargateRouter();

        // Deploy adapter
        adapterA = new StargateAdapter(
            address(stargateRouterA),
            address(routerA),
            governor
        );

        // Add supported chains and assets
        adapterA.addSupportedChain(CHAIN_ID_A, CHAIN_ID_A); // Map local chain ID to Stargate chain ID
        adapterA.addSupportedChain(CHAIN_ID_B, CHAIN_ID_B); // Map remote chain ID to Stargate chain ID

        adapterA.addSupportedAsset(CHAIN_ID_A, address(tokenA), POOL_ID_A);
        adapterA.addSupportedAsset(CHAIN_ID_B, address(tokenA), POOL_ID_B); // Same token but different pool ID on remote chain

        routerA.registerAdapter(address(adapterA));
        tokenA.mint(user, 10000e18);
        tokenA.mint(address(routerA), 10000e18);

        vm.stopPrank();

        // Deploy contracts on chain B
        useNetworkB();
        vm.startPrank(governor);

        accessManagerB = new ProtocolAccessManager(governor);
        routerB = new BridgeRouterTestHelper(address(accessManagerB));
        tokenB = new ERC20Mock();
        stargateRouterB = new MockStargateRouter();

        // Deploy adapter
        adapterB = new StargateAdapter(
            address(stargateRouterB),
            address(routerB),
            governor
        );

        // Add supported chains and assets
        adapterB.addSupportedChain(CHAIN_ID_B, CHAIN_ID_B); // Map local chain ID to Stargate chain ID
        adapterB.addSupportedChain(CHAIN_ID_A, CHAIN_ID_A); // Map remote chain ID to Stargate chain ID

        adapterB.addSupportedAsset(CHAIN_ID_B, address(tokenB), POOL_ID_B);
        adapterB.addSupportedAsset(CHAIN_ID_A, address(tokenB), POOL_ID_A); // Same token but different pool ID on remote chain

        routerB.registerAdapter(address(adapterB));
        tokenB.mint(user, 10000e18);
        tokenB.mint(address(routerB), 10000e18);

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
