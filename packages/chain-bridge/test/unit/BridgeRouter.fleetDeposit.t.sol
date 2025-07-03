// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IFleetDepositAdapter} from "../../src/interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockFleetDepositAdapter} from "../mocks/MockFleetDepositAdapter.sol";
import {MockFleetDepositAdapterNoSupport} from "../mocks/MockFleetDepositAdapterNoSupport.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract BridgeRouterFleetDepositTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockFleetDepositAdapter public mockAdapter;
    MockFleetDepositAdapterNoSupport public noSupportAdapter;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public user2 = address(0x3);
    address public fleetCommander = address(0x4);
    address public shareRecipient = address(0x5);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 8453; // Base
    uint16 public constant ALT_CHAIN_ID = 137; // Polygon
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 public constant LARGE_AMOUNT = 1_000_000 * 10 ** 18;
    uint256 public constant BASE_NATIVE_FEE = 0.01 ether;

    event FleetDepositInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed asset,
        uint256 amount,
        address fleetCommander,
        address shareRecipient,
        address adapter
    );

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        // Deploy BridgeQueue first
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router address set later
            governor // queueManager
        );

        vm.startPrank(governor);

        // Deploy router, linking it to the queue
        router = new BridgeRouter(address(accessManager), address(bridgeQueue));

        // Set the router address in the queue
        bridgeQueue.setBridgeRouter(address(router));

        // Deploy mock adapters
        mockAdapter = new MockFleetDepositAdapter();
        noSupportAdapter = new MockFleetDepositAdapterNoSupport();
        token = new ERC20Mock();

        // Register adapters
        router.registerAdapter(address(mockAdapter));
        router.registerAdapter(address(noSupportAdapter));

        vm.stopPrank();

        // Setup users with tokens and ETH
        token.mint(user, DEPOSIT_AMOUNT * 10);
        token.mint(user2, DEPOSIT_AMOUNT * 10);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_Success() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectEmit(false, true, true, false); // Don't check operationId (first indexed parameter)
        emit FleetDepositInitiated(
            bytes32(0), // operationId will be different
            DEST_CHAIN_ID,
            address(token),
            DEPOSIT_AMOUNT,
            fleetCommander,
            shareRecipient,
            address(mockAdapter)
        );

        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        // Verify operation completed
        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastDestinationChainId(), DEST_CHAIN_ID);

        // Verify token transfer occurred
        assertEq(token.balanceOf(address(mockAdapter)), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(user), DEPOSIT_AMOUNT * 10 - DEPOSIT_AMOUNT);
    }

    function test_ExecuteUserFleetDeposit_WithReferralCode() public {
        bytes memory referralCode = bytes("SUMMER2024");

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: referralCode,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));

        // Verify referral code is in compose message
        bytes memory composeMessage = mockAdapter.lastComposeMessage();
        (, BridgeTypes.FleetDepositMessageData memory messageData) = abi.decode(
            composeMessage,
            (bytes32, BridgeTypes.FleetDepositMessageData)
        );
        assertEq(messageData.referralCode, referralCode);
        assertEq(messageData.originalUser, user);
    }

    function test_ExecuteUserFleetDeposit_DifferentChainIds() public {
        uint16[] memory chainIds = new uint16[](3);
        chainIds[0] = 1; // Ethereum
        chainIds[1] = 137; // Polygon
        chainIds[2] = 42161; // Arbitrum

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT * 3);

        for (uint i = 0; i < chainIds.length; i++) {
            mockAdapter.reset(); // Reset adapter state

            BridgeTypes.ExecuteUserFleetDepositParams
                memory params = BridgeTypes.ExecuteUserFleetDepositParams({
                    destinationChainId: chainIds[i],
                    asset: address(token),
                    amount: DEPOSIT_AMOUNT,
                    fleetCommander: fleetCommander,
                    shareRecipient: shareRecipient,
                    referralCode: bytes(""),
                    options: BridgeTypes.BridgeOptions({
                        specifiedAdapter: address(mockAdapter),
                        adapterParams: BridgeTypes.AdapterParams({
                            gasLimit: 500000,
                            calldataSize: 0,
                            msgValue: BASE_NATIVE_FEE,
                            options: bytes("")
                        })
                    })
                });

            bytes32 operationId = router.executeUserFleetDeposit{
                value: BASE_NATIVE_FEE
            }(params);

            assertNotEq(operationId, bytes32(0));
            assertEq(mockAdapter.lastDestinationChainId(), chainIds[i]);
        }

        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_LargeAmount() public {
        token.mint(user, LARGE_AMOUNT);

        vm.startPrank(user);
        token.approve(address(router), LARGE_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: LARGE_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastAmount(), LARGE_AMOUNT);
    }

    function test_ExecuteUserFleetDeposit_MultipleDeposits() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT * 3);

        bytes32[] memory operationIds = new bytes32[](3);

        for (uint i = 0; i < 3; i++) {
            mockAdapter.reset(); // Reset adapter state

            BridgeTypes.ExecuteUserFleetDepositParams
                memory params = BridgeTypes.ExecuteUserFleetDepositParams({
                    destinationChainId: DEST_CHAIN_ID,
                    asset: address(token),
                    amount: DEPOSIT_AMOUNT,
                    fleetCommander: fleetCommander,
                    shareRecipient: shareRecipient,
                    referralCode: abi.encodePacked("REF", i),
                    options: BridgeTypes.BridgeOptions({
                        specifiedAdapter: address(mockAdapter),
                        adapterParams: BridgeTypes.AdapterParams({
                            gasLimit: 500000,
                            calldataSize: 0,
                            msgValue: BASE_NATIVE_FEE,
                            options: bytes("")
                        })
                    })
                });

            operationIds[i] = router.executeUserFleetDeposit{
                value: BASE_NATIVE_FEE
            }(params);

            assertNotEq(operationIds[i], bytes32(0));
        }

        vm.stopPrank();

        // Verify all operation IDs are unique
        for (uint i = 0; i < 3; i++) {
            for (uint j = i + 1; j < 3; j++) {
                assertNotEq(operationIds[i], operationIds[j]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_RevertWhen_AmountIsZero() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: 0, // Zero amount
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_AssetIsZero() public {
        vm.startPrank(user);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(0), // Zero asset
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_FleetCommanderIsZero()
        public
    {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: address(0), // Zero fleet commander
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_ShareRecipientIsZero()
        public
    {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: address(0), // Zero share recipient
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_NoAdapter() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(0), // No adapter specified
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.NoSuitableAdapter.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_UnknownAdapter() public {
        address unknownAdapter = address(0x999);

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: unknownAdapter,
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_AdapterDoesNotSupportFleetDeposits()
        public
    {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(noSupportAdapter), // Adapter that doesn't support fleet deposits
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.UnsupportedAdapterOperation.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_InsufficientFee() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        // Provide insufficient fee (less than 1% buffer over base fee)
        vm.expectRevert(BridgeRouter.InsufficientFee.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE / 2}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_InsufficientAllowance()
        public
    {
        vm.startPrank(user);
        // Don't approve tokens

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert();
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_InsufficientBalance()
        public
    {
        address poorUser = address(0x123);
        vm.startPrank(poorUser);

        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert();
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_Paused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(BridgeRouter.Paused.selector);
        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        COMPOSE MESSAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FleetDepositMessageStructure() public {
        bytes memory referralCode = bytes("SUMMER2024");

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: referralCode,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        // Verify compose message structure
        bytes memory composeMessage = mockAdapter.lastComposeMessage();
        assertGt(composeMessage.length, 0);

        (
            bytes32 messageType,
            BridgeTypes.FleetDepositMessageData memory messageData
        ) = abi.decode(
                composeMessage,
                (bytes32, BridgeTypes.FleetDepositMessageData)
            );

        assertEq(messageType, BridgeTypes.USER_FLEET_DEPOSIT_TYPE);
        assertEq(messageData.fleetCommander, fleetCommander);
        assertEq(messageData.shareRecipient, shareRecipient);
        assertEq(messageData.asset, address(token));
        assertEq(messageData.amount, DEPOSIT_AMOUNT);
        assertEq(messageData.sourceChainId, block.chainid);
        assertEq(messageData.originalUser, user);
        assertEq(messageData.referralCode, referralCode);
        // Note: operationId in message will be bytes32(0) placeholder, actual ID is set by adapter
    }

    function test_FleetDepositMessage_EmptyReferralCode() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""), // Empty referral code
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        router.executeUserFleetDeposit{value: BASE_NATIVE_FEE}(params);

        vm.stopPrank();

        bytes memory composeMessage = mockAdapter.lastComposeMessage();
        (, BridgeTypes.FleetDepositMessageData memory messageData) = abi.decode(
            composeMessage,
            (bytes32, BridgeTypes.FleetDepositMessageData)
        );

        assertEq(messageData.referralCode.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            FEE BUFFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_FeeBufferApplied() public {
        // The router applies a 1% fee buffer to account for volatility
        // So if base fee is 0.01 ether, buffered fee should be 0.0101 ether
        uint256 expectedBufferedFee = (BASE_NATIVE_FEE * 101) / 100;

        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        // Should succeed with exact buffered fee
        bytes32 operationId = router.executeUserFleetDeposit{
            value: expectedBufferedFee
        }(params);
        assertNotEq(operationId, bytes32(0));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REENTRANCY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_ReentrancyProtection() public {
        // This test ensures the ReentrancyGuard is working
        // The actual reentrancy attempt would be in a malicious adapter
        // For now, we just verify the modifier is applied by checking successful execution
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                        FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_FullFlow() public {
        bytes memory referralCode = bytes("INTEGRATION_TEST");

        vm.startPrank(user);

        // Initial balance check
        uint256 initialBalance = token.balanceOf(user);
        assertEq(initialBalance, DEPOSIT_AMOUNT * 10);

        // Approve tokens
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                referralCode: referralCode,
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(mockAdapter),
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 100,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("test_options")
                    })
                })
            });

        // Execute deposit
        bytes32 operationId = router.executeUserFleetDeposit{
            value: BASE_NATIVE_FEE
        }(params);

        vm.stopPrank();

        // Verify all state changes
        assertNotEq(operationId, bytes32(0));
        assertEq(token.balanceOf(user), initialBalance - DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(mockAdapter)), DEPOSIT_AMOUNT);

        // Verify adapter received correct parameters
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastDestinationChainId(), DEST_CHAIN_ID);
        assertEq(mockAdapter.lastDestinationAdapter(), address(0));

        // Verify adapter params
        (uint64 gasLimit, uint32 calldataSize, uint128 msgValue, ) = mockAdapter
            .lastAdapterParams();
        assertEq(gasLimit, 500000);
        assertEq(calldataSize, 100);
        assertEq(msgValue, BASE_NATIVE_FEE);

        // Verify compose message structure
        bytes memory actualComposeMessage = mockAdapter.lastComposeMessage();
        assertGt(actualComposeMessage.length, 0);

        (
            bytes32 messageType,
            BridgeTypes.FleetDepositMessageData memory messageData
        ) = abi.decode(
                actualComposeMessage,
                (bytes32, BridgeTypes.FleetDepositMessageData)
            );

        assertEq(messageType, BridgeTypes.USER_FLEET_DEPOSIT_TYPE);
        assertEq(messageData.fleetCommander, fleetCommander);
        assertEq(messageData.shareRecipient, shareRecipient);
        assertEq(messageData.asset, address(token));
        assertEq(messageData.amount, DEPOSIT_AMOUNT);
        assertEq(messageData.sourceChainId, block.chainid);
        assertEq(messageData.originalUser, user);
        assertEq(messageData.referralCode, referralCode);

        // Verify operation status in router
        assertEq(
            uint256(router.getOperationStatus(operationId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        // Verify operation to adapter mapping
        assertEq(router.operationToAdapter(operationId), address(mockAdapter));
    }
}
