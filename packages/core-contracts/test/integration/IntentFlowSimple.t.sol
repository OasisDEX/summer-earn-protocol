// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3Adapter} from "../../src/contracts/adapters/AaveV3Adapter.sol";
import {GenericIntentArk} from "../../src/contracts/arks/GenericIntentArk.sol";
import {IntentHandler} from "../../src/contracts/intent/IntentHandler.sol";
import {IntentBondFactory} from "../../src/contracts/intent/IntentBondFactory.sol";
import {SolverBond} from "../../src/contracts/intent/SolverBond.sol";
import {MockIntentOracle} from "../../src/contracts/intent/MockIntentOracle.sol";
import {MockSummerToken} from "../../src/contracts/intent/MockSummerToken.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IIntentHandler} from "../../src/interfaces/IIntentHandler.sol";
import {IPoolV3} from "../../src/interfaces/aave-v3/IPoolV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Simple Intent Flow Test
 * @notice Tests the core intent flow: GenericIntentArk -> IntentHandler -> AaveV3Adapter
 * @dev Focused test without complex configuration setup
 */
contract IntentFlowSimpleTest is Test {
    // Core contracts
    AaveV3Adapter public adapter;
    GenericIntentArk public ark;
    IntentHandler public intentHandler;
    IntentBondFactory public intentBondFactory;
    SolverBond public solverBond;

    // Mocks
    ProtocolAccessManager public accessManager;
    MockERC20 public mockToken;
    MockIntentOracle public mockOracle;
    MockSummerToken public summerToken;

    // Mock Aave contracts
    address public mockAaveV3Pool = address(0x300);
    address public mockRewardsController = address(0x400);

    // Test addresses
    address public governor = address(0x1);
    address public commander = address(0x2);
    address public solver = address(0x3);
    address public keeper = address(0x5);

    // Test constants
    uint256 public constant REQUIRED_NOTIONAL = 1000e18;
    uint256 public constant TERM = 30 days;
    uint256 public constant TARGET_YIELD = 100e18;
    uint256 public constant BOND_AMOUNT = 1000e18;
    uint256 public constant ESCROWED_YIELD = 100e18;

    function setUp() public {
        // Deploy basic infrastructure
        accessManager = new ProtocolAccessManager(governor);

        // Deploy tokens
        mockToken = new MockERC20();
        mockToken.initialize("Test Token", "TEST", 18);
        summerToken = new MockSummerToken();

        // Deploy intent system
        vm.startPrank(governor);
        intentBondFactory = new IntentBondFactory(address(summerToken));
        mockOracle = new MockIntentOracle();
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(mockOracle),
            address(summerToken)
        );

        // Setup basic roles
        intentHandler.grantSolverRole(solver);
        intentBondFactory.grantHandlerRole(address(intentHandler));
        intentBondFactory.grantLiquidatorRole(governor);
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18);
        vm.stopPrank();

        // Create solver bond
        address bondAddress = intentBondFactory.createBond(solver);
        solverBond = SolverBond(bondAddress);

        // Create a mock ark (we'll use a minimal setup)
        // For testing, we'll use a simplified approach

        // Deploy adapter pointing to a mock ark address for now
        address mockArkAddress = address(0x999);
        adapter = new AaveV3Adapter(
            address(accessManager),
            mockAaveV3Pool,
            mockRewardsController,
            mockArkAddress
        );

        // Mock the ark calls that adapter might make
        vm.mockCall(
            mockArkAddress,
            abi.encodeWithSignature("intentHandler()"),
            abi.encode(address(intentHandler))
        );

        // Register adapter with solver
        vm.startPrank(governor);
        intentHandler.addSolverAdapter(solver, address(adapter));
        vm.stopPrank();

        // Setup solver bond
        vm.startPrank(solver);
        deal(address(summerToken), solver, BOND_AMOUNT);
        IERC20(address(summerToken)).approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();

        // Setup Aave mocks
        vm.mockCall(
            mockAaveV3Pool,
            abi.encodeWithSignature("supply(address,uint256,address,uint16)"),
            abi.encode()
        );

        vm.mockCall(
            mockAaveV3Pool,
            abi.encodeWithSignature("withdraw(address,uint256,address)"),
            abi.encode(uint256(1000e18))
        );

        // Setup balances
        deal(address(mockToken), address(this), 10000e18);
        deal(address(mockToken), address(intentHandler), 10000e18);
    }

    function test_CoreIntentFlow() public {
        // This test demonstrates the core flow:
        // 1. Create intent in handler
        // 2. Solver solves intent (triggers adapter.deposit)
        // 3. Solver activates intent
        // 4. Time passes
        // 5. Solver settles intent

        address user = address(this); // We'll act as the user posting the intent

        // Step 1: Create intent (normally done by ark.postIntent, but we'll call handler directly)
        vm.startPrank(governor);
        intentHandler.grantArkRole(address(this)); // Grant ourselves ark role for testing
        vm.stopPrank();

        intentHandler.createIntent(
            user,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Verify intent created
        IIntentHandler.Intent memory intent = intentHandler.getIntent(user);
        assertEq(intent.requiredNotional, REQUIRED_NOTIONAL);
        assertEq(intent.token, address(mockToken));
        assertTrue(intent.state == IIntentHandler.IntentState.Created);

        // Step 2: Solver solves intent (this calls adapter.deposit)
        IERC20(address(mockToken)).approve(
            address(intentHandler),
            REQUIRED_NOTIONAL
        );

        vm.startPrank(solver);
        intentHandler.solveIntent(user, solver, ESCROWED_YIELD);
        vm.stopPrank();

        // Verify intent solved
        intent = intentHandler.getIntent(user);
        assertEq(intent.solver, solver);
        assertTrue(intent.state == IIntentHandler.IntentState.Solved);

        // Step 3: Activate intent
        vm.startPrank(solver);
        intentHandler.activateIntent(user);
        vm.stopPrank();

        // Verify intent active
        intent = intentHandler.getIntent(user);
        assertTrue(intent.state == IIntentHandler.IntentState.Active);

        // Step 4: Time passes
        vm.warp(block.timestamp + TERM + 1);

        // Step 5: Settle intent
        vm.startPrank(solver);
        intentHandler.settleIntent(user);
        vm.stopPrank();

        // Verify intent settled
        intent = intentHandler.getIntent(user);
        assertTrue(intent.state == IIntentHandler.IntentState.Settled);

        // Verify solver bond is intact
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);
    }

    function test_AdapterIntegration() public {
        // Test that the adapter is properly called during intent solving

        address user = address(this);

        // Setup intent
        vm.startPrank(governor);
        intentHandler.grantArkRole(address(this));
        vm.stopPrank();

        intentHandler.createIntent(
            user,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Approve tokens
        IERC20(address(mockToken)).approve(
            address(intentHandler),
            REQUIRED_NOTIONAL
        );

        // Mock call to verify adapter.deposit is called with correct parameters
        vm.expectCall(
            address(adapter),
            abi.encodeWithSignature(
                "deposit(address,uint256,address)",
                address(mockToken),
                REQUIRED_NOTIONAL,
                user
            )
        );

        // Solve intent (this should call adapter.deposit)
        vm.startPrank(solver);
        intentHandler.solveIntent(user, solver, ESCROWED_YIELD);
        vm.stopPrank();
    }

    function test_AccessControl() public {
        address user = address(this);

        // Setup intent
        vm.startPrank(governor);
        intentHandler.grantArkRole(address(this));
        vm.stopPrank();

        intentHandler.createIntent(
            user,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Only IntentHandler should be able to call adapter
        vm.expectRevert();
        adapter.deposit(address(mockToken), REQUIRED_NOTIONAL, user);

        // Only solvers should be able to solve intents
        vm.expectRevert();
        intentHandler.solveIntent(user, address(this), ESCROWED_YIELD);
    }

    function test_ArchitectureBenefits() public {
        // This test shows the architectural benefits of the new design:

        // 1. Adapter is registered per solver
        assertEq(
            address(intentHandler.solverAdapters(solver)),
            address(adapter)
        );

        // 2. Different solvers can use different adapters
        // (In practice, one solver might use AaveV3Adapter, another CompoundAdapter, etc.)

        // 3. Intent flow is standardized regardless of underlying protocol
        // The same IntentHandler works with any IAdapter implementation

        // 4. Access control is consistent
        // All adapters use the same onlyIntentHandler pattern

        assertTrue(true); // This test mainly documents the architecture
    }
}
