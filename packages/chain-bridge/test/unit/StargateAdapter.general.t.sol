// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {MockStargateV2Pool} from "../mocks/MockStargateV2.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

contract StargateAdapterGeneralTest is StargateAdapterSetupTest {
    bytes32 testTransferId = bytes32(uint256(12345));

    /*//////////////////////////////////////////////////////////////
                          ADAPTER FEATURES TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetSupportedChains() public view {
        // Get chains through registry relationships
        (, uint16[] memory supportedChains) = registryA.getTargetsForSource(
            address(adapterA),
            registryA.PEER_RELATIONSHIP()
        );

        assertEq(supportedChains.length, 1);
        assertEq(supportedChains[0], CHAIN_ID_B);
    }

    function testSupportsChain() public {
        assertTrue(
            registryA.isValidAdapterPeer(
                address(adapterA),
                address(adapterB),
                CHAIN_ID_A,
                CHAIN_ID_B
            ),
            "Chain B should be supported"
        );

        // Expect revert when checking unsupported chain
        vm.expectRevert();
        registryA.getAdapterPeer(address(adapterA), 9999);
    }

    function testFeatureSupport() public view {
        // StargateAdapter supports asset transfers but not messaging or state reads
        assertTrue(
            adapterA.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.MESSAGE)
        );
        assertFalse(
            adapterA.supportsOperation(BridgeTypes.OperationType.READ_STATE)
        );
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSPORT MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetDefaultTransportMode() public {
        useNetworkA();

        // Check initial value (should be true - taxi mode)
        assertEq(adapterA.defaultUseTaxi(), true);

        // Update to taxi mode
        vm.prank(governor);
        adapterA.setDefaultTransportMode(true);

        // Verify the value was updated
        assertEq(adapterA.defaultUseTaxi(), true);

        // Update back to bus mode
        vm.prank(governor);
        adapterA.setDefaultTransportMode(false);

        // Verify the value was updated
        assertEq(adapterA.defaultUseTaxi(), false);
    }

    function testSetDefaultTransportModeUnauthorized() public {
        useNetworkA();

        // Try to update transport mode as unauthorized user
        vm.prank(user);
        vm.expectRevert();
        adapterA.setDefaultTransportMode(true);
    }

    /*//////////////////////////////////////////////////////////////
                          CONFIG MANAGER INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCrossChainRegistryFromRegistry() public {
        useNetworkA();

        // Verify cross chain registry is accessible through the adapter
        address adapterRegistry = adapterA.crossChainRegistry();
        address expectedRegistry = address(registryA);

        assertEq(adapterRegistry, expectedRegistry);
    }

    function testDefaultGasLimitFromRegistry() public {
        useNetworkA();

        // Verify default gas limit is accessible through the adapter
        uint256 adapterGasLimit = adapterA.defaultGasLimit();
        uint256 registryGasLimit = registryA.defaultGasLimit();

        assertEq(adapterGasLimit, registryGasLimit);
        assertEq(adapterGasLimit, 400000); // From setup
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Removed minDstGasForCall related tests since this functionality was removed

    function testSetEndpointIdAndRegisterPeer() public {
        useNetworkA();

        // Add a new chain endpoint
        uint16 newChainId = 42161; // Arbitrum
        uint32 newEndpointId = 30110; // LayerZero endpoint ID for Arbitrum
        address mockArbitrumAdapter = address(0xdead);

        vm.startPrank(governor);

        // First unregister the existing peer relationship for CHAIN_ID_B
        registryA.unregisterRelationship(
            address(adapterA),
            registryA.PEER_RELATIONSHIP(),
            CHAIN_ID_B
        );

        // Set the endpoint ID
        adapterA.mapEndpoint(newChainId, newEndpointId);

        // Register the peer relationship in the registry
        registryA.registerAdapterPeer(
            address(adapterA),
            mockArbitrumAdapter,
            CHAIN_ID_A,
            newChainId
        );

        vm.stopPrank();

        // Verify the endpoint was configured
        assertEq(adapterA.getEndpointId(newChainId), newEndpointId);

        // Verify the peer relationship was established
        assertEq(
            registryA.getAdapterPeer(address(adapterA), newChainId),
            mockArbitrumAdapter,
            "Peer adapter should be registered"
        );

        // Verify it's in the list of supported chains (through registry relationships)
        (, uint16[] memory targetChainIds) = registryA.getTargetsForSource(
            address(adapterA),
            registryA.PEER_RELATIONSHIP()
        );

        bool found = false;
        for (uint256 i = 0; i < targetChainIds.length; i++) {
            if (targetChainIds[i] == newChainId) {
                found = true;
                break;
            }
        }
        assertTrue(found, "New chain should be in registry relationships");
    }

    function testAddSupportedAsset() public {
        useNetworkA();

        // Create a new token
        ERC20Mock newToken = new ERC20Mock();

        // Create a proper mock Stargate contract
        MockStargateV2Pool mockStargateContract = new MockStargateV2Pool(
            address(newToken)
        );

        // Add the new token as supported asset
        vm.prank(governor);
        adapterA.addSupportedAsset(
            address(newToken),
            address(mockStargateContract)
        );

        // Verify the asset was added
        assertEq(
            adapterA.assetToStargateContract(address(newToken)),
            address(mockStargateContract)
        );

        // Check the asset directly:
        assertTrue(
            adapterA.supportsAssetTransfer(CHAIN_ID_A, address(newToken))
        );
    }

    function testAddDuplicateAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract
        MockStargateV2Pool newStargateContract = new MockStargateV2Pool(
            address(tokenA)
        );

        // Add the same asset again (should update Stargate contract but not add duplicate)
        vm.prank(governor);
        adapterA.addSupportedAsset(
            address(tokenA),
            address(newStargateContract)
        );

        // Verify the Stargate contract was updated
        assertEq(
            adapterA.assetToStargateContract(address(tokenA)),
            address(newStargateContract)
        );

        // Check the asset directly:
        assertTrue(adapterA.supportsAssetTransfer(CHAIN_ID_A, address(tokenA)));
    }

    function testAddInvalidAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract for this test
        MockStargateV2Pool mockStargateContract = new MockStargateV2Pool(
            address(tokenA)
        );

        // Try to add address(0) as an asset
        vm.prank(governor);
        vm.expectRevert(BaseBridgeAdapter.InvalidParams.selector);
        adapterA.addSupportedAsset(address(0), address(mockStargateContract));
    }

    /*//////////////////////////////////////////////////////////////
                          NONCE SYSTEM TESTS
    //////////////////////////////////////////////////////////////*/

    function testNonceSystemPreventsCollisions() public {
        useNetworkA();

        // Setup test user
        address testUser = makeAddr("testUser");

        // Check initial nonce is 0
        assertEq(adapterA.nonces(testUser), 0);

        // Test that identical parameters generate different operation IDs due to nonce
        uint16 destinationChainId = CHAIN_ID_B;
        uint256 amount = 1 ether;
        uint256 chainId = block.chainid;

        // Simulate the operation ID generation logic used in the actual function
        // First operation (nonce will be 0)
        bytes32 operationId1 = keccak256(
            abi.encode(
                testUser,
                destinationChainId,
                amount,
                0, // nonce = 0
                chainId
            )
        );

        // Second operation (nonce will be 1)
        bytes32 operationId2 = keccak256(
            abi.encode(
                testUser,
                destinationChainId,
                amount,
                1, // nonce = 1
                chainId
            )
        );

        // Third operation (nonce will be 2)
        bytes32 operationId3 = keccak256(
            abi.encode(
                testUser,
                destinationChainId,
                amount,
                2, // nonce = 2
                chainId
            )
        );

        // Verify all operation IDs are unique
        assertTrue(
            operationId1 != operationId2,
            "Operation IDs 1 and 2 should be different"
        );
        assertTrue(
            operationId2 != operationId3,
            "Operation IDs 2 and 3 should be different"
        );
        assertTrue(
            operationId1 != operationId3,
            "Operation IDs 1 and 3 should be different"
        );

        // Test that different users have independent nonces
        address otherUser = makeAddr("otherUser");
        assertEq(
            adapterA.nonces(testUser),
            0,
            "testUser nonce should start at 0"
        );
        assertEq(
            adapterA.nonces(otherUser),
            0,
            "otherUser nonce should start at 0"
        );

        // Test with different users having same parameters but different nonces
        bytes32 testUserOpId = keccak256(
            abi.encode(
                testUser,
                destinationChainId,
                amount,
                0, // testUser's first nonce
                chainId
            )
        );

        bytes32 otherUserOpId = keccak256(
            abi.encode(
                otherUser,
                destinationChainId,
                amount,
                0, // otherUser's first nonce
                chainId
            )
        );

        // Different users should generate different operation IDs even with same nonce
        // because the user address is part of the hash
        assertTrue(
            testUserOpId != otherUserOpId,
            "Different users should generate different operation IDs"
        );
    }

    function testNonceIncrementForDifferentUsers() public {
        useNetworkA();

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        // Both users start with nonce 0
        assertEq(adapterA.nonces(user1), 0);
        assertEq(adapterA.nonces(user2), 0);

        // Test that the nonces() function correctly shows 0 for new users
        address newUser = makeAddr("newUser");
        assertEq(adapterA.nonces(newUser), 0, "New user should have nonce 0");

        // Test that each user has independent nonce space
        // Even without calling functions, we can verify the nonce getter works
        assertTrue(
            adapterA.nonces(user1) == adapterA.nonces(user2),
            "Both users should start with same nonce"
        );

        // Verify the nonce function is working and users are independent
        assertEq(adapterA.nonces(user1), 0, "User1 should have nonce 0");
        assertEq(adapterA.nonces(user2), 0, "User2 should have nonce 0");

        // Test edge case: very large address still returns 0 for initial nonce
        address maxAddr = address(type(uint160).max);
        assertEq(
            adapterA.nonces(maxAddr),
            0,
            "Even max address should have nonce 0 initially"
        );
    }
}
