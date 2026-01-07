// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SuperchainAdapter} from "../../../src/adapters/SuperchainAdapter.sol";
import {MockCrossChainRegistry} from "../../mocks/MockCrossChainRegistry.sol";
import {MockSuperchainTokenBridge} from "../../mocks/MockSuperchainTokenBridge.sol";
import {MockL2ToL2CrossDomainMessenger} from "../../mocks/MockL2ToL2CrossDomainMessenger.sol";
import {BridgeRouterTestHelper} from "../../helpers/BridgeRouterTestHelper.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";

// Base test contract with common setup used by all SuperchainAdapter tests
contract SuperchainAdapterSetupTest is Test {
    // Chain A contracts
    SuperchainAdapter public adapterA;
    BridgeRouterTestHelper public routerA;
    MockCrossChainRegistry public registryA;
    ERC20Mock public tokenA;
    ProtocolAccessManager public accessManagerA;
    MockSuperchainTokenBridge public superchainBridgeA;
    MockL2ToL2CrossDomainMessenger public l2ToL2MessengerA;

    // Chain B contracts
    SuperchainAdapter public adapterB;
    BridgeRouterTestHelper public routerB;
    MockCrossChainRegistry public registryB;
    ERC20Mock public tokenB;
    ProtocolAccessManager public accessManagerB;
    MockSuperchainTokenBridge public superchainBridgeB;
    MockL2ToL2CrossDomainMessenger public l2ToL2MessengerB;

    // Test wallets
    address public governor = address(0x1);
    address public user = address(0x2);
    address public recipient = address(0x3);
    address public keeper = address(0x4);

    // Chain IDs for testing
    uint16 public constant CHAIN_ID_A = 31337;
    uint16 public constant CHAIN_ID_B = 31338;

    // External IDs for Superchain bridge
    uint32 public constant EXTERNAL_ID_A = 100;
    uint32 public constant EXTERNAL_ID_B = 200;

    // Network chain IDs for vm.chainId()
    uint256 public constant NETWORK_A_CHAIN_ID = 31337;
    uint256 public constant NETWORK_B_CHAIN_ID = 31338;

    function setUp() public virtual {
        _setupChainA();
        _setupChainB();
        _configureCrossChainRelationships();
    }

    function _setupChainA() internal {
        vm.chainId(NETWORK_A_CHAIN_ID);

        // Deploy contracts for chain A
        accessManagerA = new ProtocolAccessManager(governor);
        registryA = new MockCrossChainRegistry();
        superchainBridgeA = new MockSuperchainTokenBridge();
        l2ToL2MessengerA = new MockL2ToL2CrossDomainMessenger();
        tokenA = new ERC20Mock();

        vm.startPrank(governor);

        // Deploy router
        routerA = new BridgeRouterTestHelper(
            address(accessManagerA),
            address(registryA)
        );

        // Configure registry
        registryA.setBridgeRouter(address(routerA));

        // Deploy adapter
        adapterA = new SuperchainAdapter(
            address(registryA),
            address(accessManagerA),
            address(superchainBridgeA),
            address(l2ToL2MessengerA)
        );

        // Configure adapter
        adapterA.mapExternalId(CHAIN_ID_A, EXTERNAL_ID_A);
        adapterA.mapExternalId(CHAIN_ID_B, EXTERNAL_ID_B);

        // Register adapter with router
        routerA.registerAdapter(address(adapterA));

        // Add supported asset
        adapterA.setAssetSupport(address(tokenA), true);

        // Mint tokens to user
        tokenA.mint(user, 10000e18);

        vm.stopPrank();
    }

    function _setupChainB() internal {
        vm.chainId(NETWORK_B_CHAIN_ID);

        // Deploy contracts for chain B
        accessManagerB = new ProtocolAccessManager(governor);
        registryB = new MockCrossChainRegistry();
        superchainBridgeB = new MockSuperchainTokenBridge();
        l2ToL2MessengerB = new MockL2ToL2CrossDomainMessenger();
        tokenB = new ERC20Mock();

        vm.startPrank(governor);

        // Deploy router
        routerB = new BridgeRouterTestHelper(
            address(accessManagerB),
            address(registryB)
        );

        // Configure registry
        registryB.setBridgeRouter(address(routerB));

        // Deploy adapter
        adapterB = new SuperchainAdapter(
            address(registryB),
            address(accessManagerB),
            address(superchainBridgeB),
            address(l2ToL2MessengerB)
        );

        // Configure adapter
        adapterB.mapExternalId(CHAIN_ID_A, EXTERNAL_ID_A);
        adapterB.mapExternalId(CHAIN_ID_B, EXTERNAL_ID_B);

        // Register adapter with router
        routerB.registerAdapter(address(adapterB));

        // Add supported asset
        adapterB.setAssetSupport(address(tokenB), true);

        // Mint tokens to user
        tokenB.mint(user, 10000e18);

        vm.stopPrank();
    }

    function _configureCrossChainRelationships() internal {
        vm.startPrank(governor);

        // Configure peer relationships
        registryA.registerRelationship(
            address(adapterA),
            address(adapterB),
            CHAIN_ID_B,
            CHAIN_ID_B,
            registryA.PEER_RELATIONSHIP()
        );

        registryB.registerRelationship(
            address(adapterB),
            address(adapterA),
            CHAIN_ID_A,
            CHAIN_ID_A,
            registryB.PEER_RELATIONSHIP()
        );

        // Set peer adapters
        registryA.setAdapterPeer(
            address(adapterA),
            CHAIN_ID_B,
            address(adapterB)
        );
        registryB.setAdapterPeer(
            address(adapterB),
            CHAIN_ID_A,
            address(adapterA)
        );

        vm.stopPrank();
    }

    // Helper function to switch to chain A context
    function useChainA() internal {
        vm.chainId(NETWORK_A_CHAIN_ID);
    }

    // Helper function to switch to chain B context
    function useChainB() internal {
        vm.chainId(NETWORK_B_CHAIN_ID);
    }

    // Helper function to simulate cross-chain message delivery
    function simulateCrossChainMessage(
        address sourceAdapter,
        uint16 sourceChainId,
        address targetAdapter,
        bytes memory message
    ) internal {
        // Set the cross-domain context for the target adapter
        if (targetAdapter == address(adapterA)) {
            l2ToL2MessengerA.setCrossDomainMessageSender(sourceAdapter);
            l2ToL2MessengerA.setCrossDomainMessageSource(sourceChainId);
        } else if (targetAdapter == address(adapterB)) {
            l2ToL2MessengerB.setCrossDomainMessageSender(sourceAdapter);
            l2ToL2MessengerB.setCrossDomainMessageSource(sourceChainId);
        }

        // Call relayMessage on the target adapter
        vm.prank(
            address(
                targetAdapter == address(adapterA)
                    ? l2ToL2MessengerA
                    : l2ToL2MessengerB
            )
        );
        if (targetAdapter == address(adapterA)) {
            adapterA.relayMessage(message);
        } else {
            adapterB.relayMessage(message);
        }
    }

    // Helper function to create transfer parameters
    function createTransferParams(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target,
        address originator,
        address refundAddress
    ) internal pure returns (BridgeTypes.ExecuteTransferParams memory) {
        return
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: destinationChainId,
                asset: asset,
                amount: amount,
                target: target,
                originator: originator,
                message: "",
                refundAddress: refundAddress
            });
    }

    // Helper function to create bridge options
    function createBridgeOptions(
        address adapter
    ) internal pure returns (BridgeTypes.BridgeOptions memory) {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: adapter,
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: "",
                payInProtocolToken: false,
                feeTokenAmount: 0
            });
    }

    // Helper function to fund router and approve adapter
    function fundRouterAndApprove(
        ERC20Mock token,
        address router,
        address adapter,
        address from,
        uint256 amount
    ) internal {
        vm.prank(from);
        require(token.transfer(router, amount));
        vm.prank(router);
        token.approve(adapter, amount);
    }
}
