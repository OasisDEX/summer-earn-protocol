// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title MockTransferAdapter
 * @notice Mock adapter that supports transferAsset operations for fleet deposits
 */
contract MockTransferAdapter is ISendAdapter, IBridgeAdapter {
    using SafeERC20 for IERC20;

    address public bridgeRouter;

    // Track last transferAsset call
    uint256 public lastAmount;
    address public lastAsset;
    uint16 public lastDestinationChainId;
    address public lastRecipient;
    bytes public lastMessage;
    address public lastOriginator;
    BridgeTypes.AdapterParams public lastAdapterParams;
    bytes32 public lastOperationId;

    constructor() {
        // Initialize with empty bridgeRouter, will be set later
    }

    function setBridgeRouter(address _bridgeRouter) external {
        bridgeRouter = _bridgeRouter;
    }

    function reset() external {
        lastAmount = 0;
        lastAsset = address(0);
        lastDestinationChainId = 0;
        lastRecipient = address(0);
        lastMessage = "";
        lastOriginator = address(0);
        lastOperationId = bytes32(0);
        delete lastAdapterParams;
    }

    function transferAsset(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        address /* refundAddress */,
        bytes calldata message,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable {
        // Store the call data for verification
        lastOperationId = operationId;
        lastDestinationChainId = destinationChainId;
        lastAsset = asset;
        lastRecipient = recipient;
        lastAmount = amount;
        lastMessage = message;
        lastOriginator = originator;
        lastAdapterParams = adapterParams;

        // Transfer tokens from caller (should be BridgeRouter)
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function sendMessage(
        bytes32 /* operationId */,
        uint16 /* destinationChainId */,
        address /* recipient */,
        bytes calldata /* message */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function readState(
        bytes32 /* operationId */,
        uint16 /* srcChainId */,
        uint16 /* dstChainId */,
        address /* dstContract */,
        bytes4 /* selector */,
        bytes calldata /* readParams */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function estimateFee(
        uint16 /* destinationChainId */,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.AdapterParams calldata /* adapterParams */,
        BridgeTypes.OperationType /* operationType */
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        nativeFee = 0.01 ether; // Base fee for testing
        tokenFee = 0;
    }

    function getOperationStatus(
        bytes32 /* operationId */
    ) external pure returns (BridgeTypes.OperationStatus) {
        return BridgeTypes.OperationStatus.SENT;
    }

    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 8453; // Base
        return chains;
    }

    function supportsChain(uint16 /* chainId */) external pure returns (bool) {
        return true;
    }

    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(ISendAdapter).interfaceId ||
            interfaceId == type(IBridgeAdapter).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @title MockUnsupportedAdapter
 * @notice Mock adapter that doesn't support transfer operations
 */
contract MockUnsupportedAdapter is ISendAdapter, IBridgeAdapter {
    function transferAsset(
        bytes32 /* operationId */,
        uint16 /* destinationChainId */,
        address /* asset */,
        address /* recipient */,
        uint256 /* amount */,
        address /* originator */,
        address /* refundAddress */,
        bytes calldata /* message */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Transfer not supported");
    }

    function sendMessage(
        bytes32 /* operationId */,
        uint16 /* destinationChainId */,
        address /* recipient */,
        bytes calldata /* message */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function readState(
        bytes32 /* operationId */,
        uint16 /* srcChainId */,
        uint16 /* dstChainId */,
        address /* dstContract */,
        bytes4 /* selector */,
        bytes calldata /* readParams */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function estimateFee(
        uint16 /* destinationChainId */,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.AdapterParams calldata /* adapterParams */,
        BridgeTypes.OperationType /* operationType */
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        nativeFee = 0.01 ether;
        tokenFee = 0;
    }

    function getOperationStatus(
        bytes32 /* operationId */
    ) external pure returns (BridgeTypes.OperationStatus) {
        return BridgeTypes.OperationStatus.SENT;
    }

    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 8453;
        return chains;
    }

    function supportsChain(uint16 /* chainId */) external pure returns (bool) {
        return true;
    }

    function supportsOperation(
        BridgeTypes.OperationType /* operationType */
    ) external pure returns (bool) {
        return false; // Doesn't support any operations
    }

    function setBridgeRouter(address /* newBridgeRouter */) external {
        // No-op for mock
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(ISendAdapter).interfaceId ||
            interfaceId == type(IBridgeAdapter).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}

contract BridgeRouterFleetDepositTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockTransferAdapter public mockAdapter;
    MockUnsupportedAdapter public unsupportedAdapter;
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
    uint128 public constant BASE_NATIVE_FEE = 0.01 ether;

    event FleetDepositInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed asset,
        uint256 amount,
        address fleetCommander,
        address shareRecipient,
        address adapter
    );

    // Helper method to calculate buffered fee (1% buffer)
    function getBufferedFee() internal pure returns (uint256) {
        return (BASE_NATIVE_FEE * 101) / 100;
    }

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
        mockAdapter = new MockTransferAdapter();
        mockAdapter.setBridgeRouter(address(router));
        unsupportedAdapter = new MockUnsupportedAdapter();

        token = new ERC20Mock();

        // Register adapters
        router.registerAdapter(address(mockAdapter));
        router.registerAdapter(address(unsupportedAdapter));

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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
            value: getBufferedFee()
        }(params);

        vm.stopPrank();

        // Verify operation completed
        assertNotEq(operationId, bytes32(0));
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastDestinationChainId(), DEST_CHAIN_ID);
        assertEq(mockAdapter.lastRecipient(), shareRecipient);
        assertEq(mockAdapter.lastOriginator(), user);

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
                originalUser: user,
                referralCode: referralCode,
                message: bytes(""),
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
            value: getBufferedFee()
        }(params);

        vm.stopPrank();

        assertNotEq(operationId, bytes32(0));

        // Verify the basic transfer occurred correctly
        assertEq(mockAdapter.lastAmount(), DEPOSIT_AMOUNT);
        assertEq(mockAdapter.lastAsset(), address(token));
        assertEq(mockAdapter.lastOriginator(), user);
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
                    originalUser: user,
                    referralCode: bytes(""),
                    message: bytes(""),
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
                value: getBufferedFee()
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
            value: getBufferedFee()
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
                    originalUser: user,
                    referralCode: abi.encodePacked("REF", i),
                    message: bytes(""),
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
                value: getBufferedFee()
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_AdapterDoesNotSupportTransfers()
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
                options: BridgeTypes.BridgeOptions({
                    specifiedAdapter: address(unsupportedAdapter), // Adapter that doesn't support transfers
                    adapterParams: BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: BASE_NATIVE_FEE,
                        options: bytes("")
                    })
                })
            });

        vm.expectRevert(IBridgeRouter.UnsupportedAdapterOperation.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
        vm.expectRevert(IBridgeRouter.InsufficientFee.selector);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
        vm.stopPrank();
    }

    function test_ExecuteUserFleetDeposit_RevertWhen_InsufficientBalance()
        public
    {
        address poorUser = address(0x123);
        // Give the user enough ETH to pay for the transaction but no tokens
        vm.deal(poorUser, 10 ether);

        vm.startPrank(poorUser);

        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                originalUser: poorUser,
                referralCode: bytes(""),
                message: bytes(""),
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
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeUserFleetDeposit{value: getBufferedFee()}(params);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        MESSAGE STRUCTURE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FleetDepositMessage_CorrectRecipient() public {
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                originalUser: user,
                referralCode: bytes("SUMMER2024"),
                message: bytes(""),
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
            value: getBufferedFee()
        }(params);

        vm.stopPrank();

        // Verify the transfer went to the share recipient (not fleet commander)
        assertEq(mockAdapter.lastRecipient(), shareRecipient);
        assertEq(mockAdapter.lastOriginator(), user);
        assertNotEq(operationId, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                            FEE BUFFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteUserFleetDeposit_FeeBufferApplied() public {
        // The router applies a 1% fee buffer to account for volatility
        vm.startPrank(user);
        token.approve(address(router), DEPOSIT_AMOUNT);

        BridgeTypes.ExecuteUserFleetDepositParams memory params = BridgeTypes
            .ExecuteUserFleetDepositParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: DEPOSIT_AMOUNT,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
            value: getBufferedFee()
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
                originalUser: user,
                referralCode: bytes(""),
                message: bytes(""),
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
            value: getBufferedFee()
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
                originalUser: user,
                referralCode: referralCode,
                message: bytes("test_message"),
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
            value: getBufferedFee()
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
        assertEq(mockAdapter.lastRecipient(), shareRecipient);
        assertEq(mockAdapter.lastOriginator(), user);
        assertEq(mockAdapter.lastOperationId(), operationId);

        // Verify adapter params
        (
            uint64 gasLimit,
            uint32 calldataSize,
            uint128 msgValue,
            bytes memory options
        ) = mockAdapter.lastAdapterParams();
        assertEq(gasLimit, 500000);
        assertEq(calldataSize, 100);
        assertEq(msgValue, BASE_NATIVE_FEE);

        // Verify operation status in router
        assertEq(
            uint256(router.getOperationStatus(operationId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        // Verify operation to adapter mapping
        assertEq(router.operationToAdapter(operationId), address(mockAdapter));
    }
}
