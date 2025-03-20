// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
contract BridgeRouterReadStateTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public admin = address(0x2);
    address public user = address(0x3);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        accessManager = new ProtocolAccessManager(governor);
        router = new BridgeRouter(address(accessManager));
        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(admin, 10000e18);
        token.mint(user, 10000e18);

        vm.stopPrank();
    }

    // ---- READ STATE TESTS ----

    function testReadState() public {
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        // Verify request was initiated
        assertEq(
            uint256(router.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.PENDING)
        );
        assertEq(router.transferToAdapter(requestId), address(mockAdapter));
        assertEq(router.readRequestToOriginator(requestId), user);

        vm.stopPrank();
    }

    function testDeliverReadResponse() public {
        // First create a read request
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        vm.stopPrank();

        // Now deliver the response from the adapter
        vm.prank(address(mockAdapter));
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));

        // Verify response was delivered
        assertEq(
            uint256(router.transferStatuses(requestId)),
            uint256(BridgeTypes.TransferStatus.DELIVERED)
        );
    }

    function testDeliverReadResponseUnauthorized() public {
        // First create a read request
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        vm.stopPrank();

        // Should revert when non-adapter tries to deliver response
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));

        // Should revert when wrong adapter tries to deliver response
        vm.startPrank(admin);
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        vm.prank(address(mockAdapter2));
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));
    }
}
