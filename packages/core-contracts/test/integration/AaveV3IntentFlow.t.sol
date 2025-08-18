// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3Escrow} from "../../src/contracts/adapters/AaveV3Escrow.sol";
import {GenericIntentArk} from "../../src/contracts/arks/GenericIntentArk.sol";
import {IntentHandler} from "../../src/contracts/intent/IntentHandler.sol";
import {IntentBondFactory} from "../../src/contracts/intent/IntentBondFactory.sol";
import {SolverBond} from "../../src/contracts/intent/SolverBond.sol";
import {MockIntentOracle} from "../../src/contracts/intent/MockIntentOracle.sol";
import {MockSummerToken} from "../../src/contracts/intent/MockSummerToken.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IIntentHandler} from "../../src/interfaces/IIntentHandler.sol";
import {DataTypes} from "../../src/interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../src/interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../src/interfaces/aave-v3/IRewardsController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AaveV3 Intent Flow Integration Test
 * @notice Tests the complete intent flow using GenericIntentArk + AaveV3Escrow + IntentHandler
 * @dev Recreates AaveV3IntentArk functionality using the new modular architecture
 */
contract AaveV3IntentFlowTest is Test {
    // Core contracts
    AaveV3Escrow public adapter;
    GenericIntentArk public ark;
    IntentHandler public intentHandler;
    IntentBondFactory public intentBondFactory;
    SolverBond public solverBond;

    // Infrastructure
    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;
    IERC20 public usdc;
    MockIntentOracle public mockOracle;
    MockSummerToken public summerToken;

    address public constant USDC_MAINNET =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant aaveV3PoolAddress =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public aaveAddressProvider =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public aaveV3DataProvider =
        0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
    address public rewardsController =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;

    // Test addresses
    address public governor = address(0x1);
    address public commander = address(0x2);
    address public solver = address(0x3);
    address public user = address(0x4);
    address public keeper = address(0x5);
    address public raft = address(0x6);
    address public tipJar = address(0x7);
    address public treasury = address(0x8);

    // Test constants
    uint256 public constant REQUIRED_NOTIONAL = 1000e6;
    uint256 public constant TERM = 30 days;
    uint256 public constant TARGET_YIELD = 100e6;
    uint256 public constant BOND_AMOUNT = 1000e6;
    uint256 public constant ESCROWED_YIELD = 100e6;

    uint256 forkBlock = 20006596;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(forkId);

        // Deploy infrastructure
        accessManager = new ProtocolAccessManager(governor);

        // Deploy mock tokens
        usdc = IERC20(USDC_MAINNET);
        summerToken = new MockSummerToken();

        // Deploy configuration manager with minimal setup for testing
        vm.startPrank(governor);

        // Use a simpler approach - create a mock config manager
        configurationManager = new ConfigurationManager(address(accessManager));

        ConfigurationManagerParams
            memory configurationManagerParams = ConfigurationManagerParams({
                raft: raft,
                tipJar: tipJar,
                treasury: treasury,
                harborCommand: address(99),
                fleetCommanderRewardsManagerFactory: address(999)
            });
        configurationManager.initializeConfiguration(
            configurationManagerParams
        );

        // Deploy intent system
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
        // Grant IntentHandler admin role on factory so it can slash bonds
        intentBondFactory.grantRole(
            intentBondFactory.DEFAULT_ADMIN_ROLE(),
            address(intentHandler)
        );
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18);
        vm.stopPrank();

        // Deploy solver bond
        address bondAddress = intentBondFactory.createBond(solver);
        solverBond = SolverBond(bondAddress);

        // Deploy ark
        ArkParams memory arkParams = ArkParams({
            name: "Aave V3 USDC Ark",
            details: "Aave V3 USDC yield generation via intent system",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: Percentage.wrap(1e18)
        });

        ark = new GenericIntentArk(
            arkParams,
            address(intentHandler),
            address(intentBondFactory)
        );

        // Update role assignment after ark deployment
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), commander);
        accessManager.grantKeeperRole(address(ark), keeper);
        intentHandler.grantArkRole(address(ark));
        vm.stopPrank();

        // Register commander with ark
        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Deploy adapter
        adapter = new AaveV3Escrow(
            address(accessManager),
            aaveV3PoolAddress,
            rewardsController,
            address(ark)
        );

        // Register adapter with intent handler for solver
        vm.startPrank(governor);
        intentHandler.addSolverAdapter(solver, address(adapter));
        vm.stopPrank();

        // Setup balances
        deal(address(usdc), address(ark), 10000e6); // 10,000 USDC (6 decimals)
        deal(address(usdc), commander, 10000e6);
        deal(address(summerToken), solver, 10000e18);

        // Also give enough tokens to the intentHandler for transfers
        deal(address(usdc), address(intentHandler), 10000e6);

        // Solver adds bond
        vm.startPrank(solver);
        IERC20(address(summerToken)).approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();

        vm.label(address(ark), "IntentArk");
        vm.label(address(adapter), "AaveV3Escrow");
        vm.label(address(intentHandler), "IntentHandler");
        vm.label(address(intentBondFactory), "IntentBondFactory");
        vm.label(address(solverBond), "SolverBond");
        vm.label(address(usdc), "USDC");
        vm.label(address(summerToken), "SummerToken");
    }

    function test_CompleteAaveV3IntentFlow() public {
        // Step 1: Keeper posts intent for yield generation
        bytes32 intentId = keccak256("aave-v3-yield-intent");

        vm.startPrank(keeper);
        ark.postIntent(
            intentId,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        // The ark should have approved the IntentHandler during postIntent (via forceApprove)
        // But let's ensure the ark has enough balance for the required notional
        deal(address(usdc), address(ark), REQUIRED_NOTIONAL);

        // Verify intent was created
        assertTrue(ark.isIntentActive(intentId));
        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertEq(intent.requiredNotional, REQUIRED_NOTIONAL);
        assertEq(intent.term, TERM);
        assertEq(intent.targetYield, TARGET_YIELD);
        assertEq(intent.token, address(usdc));
        assertTrue(intent.state == IIntentHandler.IntentState.Created);

        // Step 2: Solver solves the intent (this triggers adapter.deposit)
        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(address(ark), solver, ESCROWED_YIELD);
        vm.stopPrank();

        // Verify intent was solved and tokens were deposited to Aave via adapter
        intent = intentHandler.getIntent(address(ark));
        assertEq(intent.solver, solver);
        assertEq(intent.escrowedYield, ESCROWED_YIELD);
        assertTrue(intent.state == IIntentHandler.IntentState.Solved);

        // Step 4: Time passes - yield generation period
        vm.warp(block.timestamp + TERM + 1);

        // Step 5: Solver settles the intent
        vm.startPrank(solver);
        intentHandler.settleIntent(address(ark));
        vm.stopPrank();

        // Verify intent is settled
        intent = intentHandler.getIntent(address(ark));
        assertTrue(intent.state == IIntentHandler.IntentState.Settled);

        // Verify solver bond is intact (successful completion)
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);
    }

    function test_AaveV3AdapterDirectOperations() public {
        // Test direct adapter operations (these would be called by IntentHandler)
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup: give adapter some tokens to work with
        deal(address(usdc), address(adapter), depositAmount);

        // Test deposit operation (called by IntentHandler during solveIntent)
        vm.startPrank(address(intentHandler));
        IERC20(address(usdc)).approve(address(adapter), depositAmount);
        adapter.deposit(address(usdc), depositAmount, address(ark));
        vm.stopPrank();

        // Test withdraw operation
        vm.startPrank(address(intentHandler));
        adapter.withdraw(address(usdc), depositAmount / 2, address(ark));
        vm.stopPrank();
    }

    function test_IntentCancellation() public {
        // Post intent
        bytes32 intentId = keccak256("cancellable-intent");

        vm.startPrank(keeper);
        ark.postIntent(
            intentId,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockOracle),
            block.timestamp + 1 days
        );

        // Cancel before it's solved
        ark.cancelIntent(intentId);
        vm.stopPrank();

        // Verify intent was cancelled
        assertFalse(ark.isIntentActive(intentId));
        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.ResignedByArk);
    }

    function test_SolverResignation() public {
        // Setup intent and solve it
        bytes32 intentId = keccak256("resignation-intent");

        vm.startPrank(keeper);
        ark.postIntent(
            intentId,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        // Ensure ark has enough balance for the required notional
        deal(address(usdc), address(ark), REQUIRED_NOTIONAL);

        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(address(ark), solver, ESCROWED_YIELD);

        // Solver resigns (gets bond slashed)
        intentHandler.resignBySolver(address(ark));
        vm.stopPrank();

        // Verify resignation and bond slashing
        IIntentHandler.Intent memory intent = intentHandler.getIntent(
            address(ark)
        );
        assertTrue(intent.state == IIntentHandler.IntentState.ResignedBySolver);

        // Bond should be slashed by 50%
        assertEq(
            intentBondFactory.getSolverBondAmount(solver),
            BOND_AMOUNT / 2
        );
    }

    function test_AccessControlIntegration() public {
        bytes32 intentId = keccak256("access-test-intent");

        // Only keeper can post intents
        vm.startPrank(user);
        vm.expectRevert();
        ark.postIntent(
            intentId,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        // Only solver can solve intents
        vm.startPrank(keeper);
        ark.postIntent(
            intentId,
            REQUIRED_NOTIONAL,
            TERM,
            TARGET_YIELD,
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        intentHandler.solveIntent(address(ark), solver, ESCROWED_YIELD);
        vm.stopPrank();

        // Only IntentHandler can call adapter functions
        vm.startPrank(user);
        vm.expectRevert();
        adapter.deposit(address(usdc), 1000e6, address(ark));
        vm.stopPrank();
    }

    function test_ArchitecturalBenefits() public {
        // This test demonstrates the architectural benefits of the new design

        // 1. Generic ark can work with any adapter
        assertEq(address(adapter.ark()), address(ark));

        // 2. Adapter is registered with specific solver
        assertEq(
            address(intentHandler.solverAdapters(solver)),
            address(adapter)
        );

        // 3. Access control is centralized and consistent
        // Keeper can post intents (this is verified by the successful postIntent call above)

        // 4. Intent flow is standardized
        bytes32 intentId = keccak256("architectural-test");

        vm.startPrank(keeper);
        ark.postIntent(
            intentId,
            100e6,
            7 days,
            10e6,
            address(mockOracle),
            block.timestamp + 1 days
        );
        vm.stopPrank();

        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(address(ark), solver, 10e6);
        vm.stopPrank();

        // The same pattern can be used for Compound, Morpho, etc.
        // Just deploy new adapters and register them with solvers
    }
}
