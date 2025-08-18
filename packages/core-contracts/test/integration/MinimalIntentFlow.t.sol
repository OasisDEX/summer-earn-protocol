// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3Escrow} from "../../src/contracts/adapters/AaveV3Escrow.sol";
import {IntentHandler} from "../../src/contracts/intent/IntentHandler.sol";
import {IntentBondFactory} from "../../src/contracts/intent/IntentBondFactory.sol";
import {SolverBond} from "../../src/contracts/intent/SolverBond.sol";
import {MockIntentOracle} from "../../src/contracts/intent/MockIntentOracle.sol";
import {MockSummerToken} from "../../src/contracts/intent/MockSummerToken.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IIntentHandler} from "../../src/interfaces/IIntentHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Minimal Intent Flow Test
 * @notice Tests the basic intent mechanism: IntentHandler -> Adapter flow
 */
contract MinimalIntentFlowTest is Test {
    IntentHandler public intentHandler;
    IntentBondFactory public intentBondFactory;
    SolverBond public solverBond;
    AaveV3Escrow public adapter;

    MockERC20 public mockToken;
    MockIntentOracle public mockOracle;
    MockSummerToken public summerToken;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public solver = address(0x2);
    address public user = address(0x3);

    uint256 public constant BOND_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy tokens
        mockToken = new MockERC20();
        mockToken.initialize("Test Token", "TEST", 18);
        summerToken = new MockSummerToken();

        // Deploy access manager
        accessManager = new ProtocolAccessManager(governor);

        // Deploy intent infrastructure
        vm.startPrank(governor);

        intentBondFactory = new IntentBondFactory(address(summerToken));
        mockOracle = new MockIntentOracle();
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(mockOracle),
            address(summerToken)
        );

        // Setup roles
        intentHandler.grantSolverRole(solver);
        intentBondFactory.grantHandlerRole(address(intentHandler));
        intentBondFactory.grantLiquidatorRole(governor);
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18);

        vm.stopPrank();

        // Create solver bond
        address bondAddress = intentBondFactory.createBond(solver);
        solverBond = SolverBond(bondAddress);

        // Deploy adapter with mock ark
        address mockArk = address(0x999);
        adapter = new AaveV3Escrow(
            address(accessManager),
            address(0x300), // mock aave pool
            address(0x400), // mock rewards controller
            mockArk
        );

        // Mock ark.intentHandler() call
        vm.mockCall(
            mockArk,
            abi.encodeWithSignature("intentHandler()"),
            abi.encode(address(intentHandler))
        );

        // Register adapter
        vm.startPrank(governor);
        intentHandler.addSolverAdapter(solver, address(adapter));
        vm.stopPrank();

        // Setup solver bond
        vm.startPrank(solver);
        deal(address(summerToken), solver, BOND_AMOUNT);
        IERC20(address(summerToken)).approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();

        // Mock Aave calls
        vm.mockCall(
            address(0x300),
            abi.encodeWithSignature("supply(address,uint256,address,uint16)"),
            abi.encode()
        );

        // Setup balances
        deal(address(mockToken), user, 10000e18);
        deal(address(mockToken), address(intentHandler), 10000e18);
    }

    function test_BasicIntentFlow() public {
        // Test the basic intent flow without GenericIntentArk
        // This isolates the IntentHandler -> Adapter mechanism

        uint256 requiredNotional = 1000e18;
        uint256 term = 30 days;
        uint256 targetYield = 100e18;
        uint256 escrowedYield = 100e18;

        // Step 1: Create intent (as if called by an ark)
        vm.startPrank(governor);
        intentHandler.grantArkRole(address(this)); // Grant this test contract ark role
        vm.stopPrank();

        intentHandler.createIntent(
            user,
            requiredNotional,
            term,
            targetYield,
            address(mockToken),
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Verify intent created
        IIntentHandler.Intent memory intent = intentHandler.getIntent(user);
        assertEq(intent.requiredNotional, requiredNotional);
        assertTrue(intent.state == IIntentHandler.IntentState.Created);

        // Step 2: Give user tokens and approval
        vm.startPrank(user);
        IERC20(address(mockToken)).approve(
            address(intentHandler),
            requiredNotional
        );
        vm.stopPrank();

        // Step 3: Solver solves intent (this calls adapter.deposit)
        vm.expectCall(
            address(adapter),
            abi.encodeWithSignature(
                "deposit(address,uint256,address)",
                address(mockToken),
                requiredNotional,
                user
            )
        );

        vm.startPrank(solver);
        intentHandler.solveIntent(user, solver, escrowedYield);
        vm.stopPrank();

        // Verify intent solved
        intent = intentHandler.getIntent(user);
        assertEq(intent.solver, solver);
        assertTrue(intent.state == IIntentHandler.IntentState.Solved);

        // Step 4: Settle after term
        vm.warp(block.timestamp + term + 1);

        vm.startPrank(solver);
        intentHandler.settleIntent(user);
        vm.stopPrank();

        assertTrue(
            intentHandler.getIntent(user).state ==
                IIntentHandler.IntentState.Settled
        );
    }

    function test_AdapterAccessControl() public {
        // Test that only IntentHandler can call adapter
        vm.expectRevert();
        adapter.deposit(address(mockToken), 1000e18, user);

        // IntentHandler should be able to call it (via the mock)
        vm.startPrank(address(intentHandler));
        adapter.deposit(address(mockToken), 1000e18, user);
        vm.stopPrank();
    }

    function test_SolverAdapterMapping() public {
        // Test that adapter is correctly registered
        assertEq(
            address(intentHandler.solverAdapters(solver)),
            address(adapter)
        );

        // Test that different solver has no adapter
        assertEq(
            address(intentHandler.solverAdapters(address(0x999))),
            address(0)
        );
    }
}
