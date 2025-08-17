// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {console} from "forge-std/console.sol";

contract BridgeRouterReadStateTest is BridgeRouterSetup {
    // ---- READ STATE TESTS ----

    function testReadState() public {
        address targetContract = address(token); // Use a valid address for setup
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);

        // mockReceiver (queueManager) initiates
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 100,
            msgValue: 0,
            options: ""
        });

        // Quote fee FOR EXECUTION
        (uint256 fee, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            targetContract, // Use target contract in quote
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        // Use specified adapter in options for queueing
        options.specifiedAdapter = specifiedAdapter;

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        bytes32 operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: keeper,
                refundAddress: keeper
            }),
            options
        );
        vm.stopPrank();

        // todo: expect calls to lz endpoint to be made
    }

    function testDeliverReadResponse() public {
        bytes32 operationId; // Declare operationId outside prank scope
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);

        // mockReceiver (queueManager) queues the operation (NO VALUE)
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 100,
            msgValue: 0,
            options: ""
        });

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
        );
        vm.stopPrank();

        // Set up the operation mappings using the test helper
        vm.prank(address(router));
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));

        // Now deliver the response from the adapter
        vm.prank(address(mockAdapter));
        // Expect the call to the receiver with correct parameter order
        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainReceiver.receiveOperation.selector,
                BridgeTypes.OperationType.READ_STATE,
                abi.encode(
                    BridgeTypes.RelayedReadResponse({
                        readResponseData: abi.encode(uint256(100)),
                        operationId: operationId,
                        sourceChainId: DEST_CHAIN_ID
                    })
                )
            )
        );
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(
                BridgeTypes.RelayedReadResponse({
                    readResponseData: abi.encode(uint256(100)),
                    operationId: operationId,
                    sourceChainId: DEST_CHAIN_ID
                })
            )
        );

        // Verify that the mockReceiver received the data
        assertEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
        // Originator of the read request was router - router calls receive in receiver
        assertEq(mockReceiver.lastSender(), address(router));
        assertEq(mockReceiver.lastSourceChainId(), DEST_CHAIN_ID);
    }

    function testDeliverReadResponseUnauthorized() public {
        bytes32 operationId; // Declare operationId
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);
        BridgeTypes.BridgeOptions memory options; // Declare options outside prank

        // mockReceiver (queueManager) queues the operation (NO VALUE)
        vm.startPrank(address(mockReceiver));
        // Create bridge options inside prank
        options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 100,
            msgValue: 0,
            options: ""
        });

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options, // Use options
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
        );
        vm.stopPrank();

        // Test case 1: Non-adapter trying to deliver response
        vm.prank(address(0x999)); // Random non-adapter address
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(uint256(100))
        );

        // Register second adapter
        vm.prank(governor);
        router.registerAdapter(address(mockAdapterDest));

        // Test case 2: Different adapter trying to deliver response
        vm.prank(address(mockAdapterDest));
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(
                BridgeTypes.RelayedReadResponse({
                    readResponseData: abi.encode(uint256(100)),
                    operationId: operationId,
                    sourceChainId: DEST_CHAIN_ID
                })
            )
        );
    }

    function testDeliverReadResponseReceiverRejects() public {
        bytes32 operationId; // Declare operationId
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);
        BridgeTypes.BridgeOptions memory options; // Declare options outside prank

        // Configure the receiver to reject the call
        mockReceiver.setReceiveSuccess(false);

        // mockReceiver (queueManager) queues the operation (NO VALUE)
        vm.startPrank(address(mockReceiver));
        // Create bridge options inside prank
        options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 100,
            msgValue: 0,
            options: ""
        });

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options, // Use options
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
        );
        vm.stopPrank();

        // Set up the operation mappings using the test helper
        vm.prank(address(router));
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));

        // Attempt to deliver the response
        vm.prank(address(mockAdapter));
        // Expect the call to the router's deliver function
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.deliver.selector,
                BridgeTypes.OperationType.READ_STATE,
                abi.encode(
                    BridgeTypes.RelayedReadResponse({
                        readResponseData: abi.encode(uint256(100)),
                        operationId: operationId,
                        sourceChainId: DEST_CHAIN_ID
                    })
                )
            )
        );
        // Expect the call to the receiver, which will revert
        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainReceiver.receiveOperation.selector,
                BridgeTypes.OperationType.READ_STATE,
                abi.encode(
                    BridgeTypes.RelayedReadResponse({
                        readResponseData: abi.encode(uint256(100)),
                        operationId: operationId,
                        sourceChainId: DEST_CHAIN_ID
                    })
                )
            )
        );
        // Do not mock a return, let it revert

        vm.expectRevert(bytes("Receiver rejected call"));
        router.deliver(
            BridgeTypes.OperationType.READ_STATE,
            abi.encode(
                BridgeTypes.RelayedReadResponse({
                    readResponseData: abi.encode(uint256(100)),
                    operationId: operationId,
                    sourceChainId: DEST_CHAIN_ID
                })
            )
        );

        assertNotEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
    }
}
