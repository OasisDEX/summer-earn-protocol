// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";

contract BridgeRouterReadStateTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;
    MockCrossChainReceiver public mockReceiver;

    address public governor = address(0x1);
    address public user = address(0x2);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    function setUp() public {
        vm.startPrank(governor);

        // Deploy contracts
        accessManager = new ProtocolAccessManager(governor);
        router = new BridgeRouter(address(accessManager));
        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();
        mockReceiver = new MockCrossChainReceiver();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(user, 10000e18);

        vm.stopPrank();
    }

    // ---- READ STATE TESTS ----

    function testReadState() public {
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.LayerZeroOptions memory lzOptions = BridgeTypes
            .LayerZeroOptions({
                optionType: OPTION_TYPE_EXECUTOR_LZ_READ,
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                adapterParams: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            bridgePreference: 0,
            lzOptions: lzOptions
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
        // Use mockReceiver instead of user as the originator
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.LayerZeroOptions memory lzOptions = BridgeTypes
            .LayerZeroOptions({
                optionType: OPTION_TYPE_EXECUTOR_LZ_READ,
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                adapterParams: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            bridgePreference: 0,
            lzOptions: lzOptions
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

        // Verify that the mockReceiver received the data
        assertEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
        assertEq(mockReceiver.lastSender(), address(mockReceiver));
        assertEq(mockReceiver.lastMessageId(), requestId);
    }

    function testDeliverReadResponseUnauthorized() public {
        // Use mockReceiver instead of user as the originator
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.LayerZeroOptions memory lzOptions = BridgeTypes
            .LayerZeroOptions({
                optionType: OPTION_TYPE_EXECUTOR_LZ_READ,
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                adapterParams: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly select mockAdapter
            bridgePreference: 0,
            lzOptions: lzOptions
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
        vm.prank(address(0x999)); // Random non-adapter address
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));

        // Register second adapter
        vm.prank(governor);
        router.registerAdapter(address(mockAdapter2));

        // Should revert when wrong adapter tries to deliver response
        vm.prank(address(mockAdapter2));
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));
    }

    function testDeliverReadResponseReceiverRejects() public {
        // Use mockReceiver instead of user as the originator
        vm.startPrank(address(mockReceiver));

        // Configure the receiver to reject the call
        mockReceiver.setReceiveSuccess(false);

        // Create bridge options
        BridgeTypes.LayerZeroOptions memory lzOptions = BridgeTypes
            .LayerZeroOptions({
                optionType: OPTION_TYPE_EXECUTOR_LZ_READ,
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                adapterParams: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            bridgePreference: 0,
            lzOptions: lzOptions
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

        // Attempt to deliver the response, should revert with ReceiverRejectedCall
        vm.prank(address(mockAdapter));
        vm.expectRevert(BridgeRouter.ReceiverRejectedCall.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));
    }
}
