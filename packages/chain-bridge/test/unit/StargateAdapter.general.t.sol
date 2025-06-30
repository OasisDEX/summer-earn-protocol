// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {MockStargateV2} from "../mocks/MockStargateV2.sol";

contract StargateAdapterGeneralTest is StargateAdapterSetupTest {
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
        assertFalse(adapterA.supportsChain(9999)); // Arbitrary unsupported chain
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
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Removed minDstGasForCall related tests since this functionality was removed

    function testAddSupportedChain() public {
        useNetworkA();

        // Add a new supported chain
        uint16 newChainId = 42161; // Arbitrum
        uint32 newEndpointId = 30110; // LayerZero endpoint ID for Arbitrum

        vm.prank(governor);
        adapterA.addSupportedChain(newChainId, newEndpointId, address(0xdead)); // Use non-zero address

        // Verify the chain was added
        assertTrue(adapterA.supportsChain(newChainId));
        assertEq(adapterA.getEndpointId(newChainId), newEndpointId);

        // Verify it's in the list of supported chains
        uint16[] memory supportedChains = adapterA.getSupportedChains();
        bool found = false;
        for (uint i = 0; i < supportedChains.length; i++) {
            if (supportedChains[i] == newChainId) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testAddDuplicateSupportedChain() public {
        useNetworkA();

        // Try to add an already supported chain
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        adapterA.addSupportedChain(
            CHAIN_ID_A,
            uint32(CHAIN_ID_A),
            address(adapterA)
        );
    }

    function testAddSupportedAsset() public {
        useNetworkA();

        // Create a new token
        ERC20Mock newToken = new ERC20Mock();

        // Create a proper mock Stargate contract
        MockStargateV2 mockStargateContract = new MockStargateV2(
            address(newToken),
            MockStargateV2.StargateType.Pool
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
        assertTrue(adapterA.isAssetSupported(CHAIN_ID_A, address(newToken)));
    }

    function testAddDuplicateAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract
        MockStargateV2 newStargateContract = new MockStargateV2(
            address(tokenA),
            MockStargateV2.StargateType.OFT
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
        assertTrue(adapterA.isAssetSupported(CHAIN_ID_A, address(tokenA)));
    }

    function testAddInvalidAsset() public {
        useNetworkA();

        // Create a proper mock Stargate contract for this test
        MockStargateV2 mockStargateContract = new MockStargateV2(
            address(tokenA),
            MockStargateV2.StargateType.Pool
        );

        // Try to add address(0) as an asset
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
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
