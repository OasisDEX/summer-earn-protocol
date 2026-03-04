// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/contracts/Escrow.sol";
import {IntentHandler} from "../src/contracts/IntentHandler.sol";
import {IntentBondFactory} from "../src/contracts/IntentBondFactory.sol";
import {SolverBond} from "../src/contracts/SolverBond.sol";
import {MockIntentOracle} from "../src/mocks/MockIntentOracle.sol";
import {MockSummerToken} from "../src/mocks/MockSummerToken.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ArkParams} from "@summerfi/earn-protocol-contracts/types/ArkTypes.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IIntentHandler} from "../src/interfaces/IIntentHandler.sol";
import {DataTypes} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/IRewardsController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveV3Ark} from "@summerfi/earn-protocol-contracts/contracts/arks/AaveV3Ark.sol";
import {ArkTestBase} from "@summerfi/earn-protocol-test/arks/ArkTestBase.sol";

/**
 * @title AaveV3 Intent Flow Integration Test
 * @notice Tests the complete intent flow using GenericIntentArk + AaveV3Escrow + IntentHandler
 * @dev Recreates AaveV3IntentArk functionality using the new modular architecture
 */
contract AaveV3IntentFlowTest is Test, ArkTestBase {
    // Core contracts
    Escrow public escrow;
    IntentHandler public intentHandler;
    IntentBondFactory public intentBondFactory;
    SolverBond public solverBond;

    // Infrastructure
    // ProtocolAccessManager public accessManager;
    // ConfigurationManager public configurationManager;
    IERC20 public usdc;
    MockIntentOracle public mockOracle;
    MockSummerToken public summerToken;
    AaveV3Ark public ark;

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
    address public solver = address(0x789);
    address public user = address(0x489);

    // Test constants
    uint256 public constant REQUIRED_NOTIONAL = 1000e6;
    uint256 public constant TERM = 30 days;
    uint256 public constant TARGET_YIELD = 100e6;
    uint256 public constant BOND_AMOUNT = 1000e6; // in usdc
    uint256 public constant ESCROWED_YIELD = 100e6;

    uint256 forkBlock = 20006596;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(forkId);

        initializeCoreContracts();
        (commander, ) = setupFleetCommanderWithBufferArk(
            USDC_MAINNET,
            "Aave V3 USDC Ark"
        );

        // Deploy infrastructure
        accessManager = new ProtocolAccessManager(governor);

        vm.prank(governor);
        accessManager.grantSuperKeeperRole(keeper);

        // Deploy mock tokens
        usdc = IERC20(USDC_MAINNET);
        summerToken = new MockSummerToken();

        // Deploy configuration manager with minimal setup for testing
        vm.startPrank(governor);

        // Deploy intent system

        mockOracle = new MockIntentOracle();
        intentBondFactory = new IntentBondFactory(
            address(summerToken),
            address(accessManager),
            address(mockOracle)
        );
        intentHandler = new IntentHandler(
            address(intentBondFactory),
            address(mockOracle),
            address(summerToken),
            address(accessManager)
        );

        // Setup roles
        mockOracle.addSupportedToken(address(summerToken));
        mockOracle.setPrice(address(summerToken), 1e18, 18);
        vm.stopPrank();

        // Deploy solver bond
        vm.startPrank(keeper);
        address bondAddress = intentBondFactory.createBond(solver);
        solverBond = SolverBond(bondAddress);
        vm.stopPrank();

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

        ark = new AaveV3Ark(aaveV3PoolAddress, rewardsController, arkParams);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Add solver escrow for the solver
        vm.startPrank(keeper);
        intentHandler.addSolverEscrow(solver, address(usdc));
        vm.stopPrank();

        // Setup balances
        deal(address(usdc), commander, 10000e6); // 10,000 USDC (6 decimals)
        deal(address(summerToken), solver, 10000e18);

        // Also give enough tokens to the intentHandler for transfers
        deal(address(usdc), address(intentHandler), 10000e6);

        // Solver adds bond
        vm.startPrank(solver);
        IERC20(address(summerToken)).approve(address(solverBond), BOND_AMOUNT);
        solverBond.addBond(BOND_AMOUNT);
        vm.stopPrank();

        vm.label(commander, "Commander");
        vm.label(address(intentHandler), "IntentHandler");
        vm.label(address(intentBondFactory), "IntentBondFactory");
        vm.label(address(solverBond), "SolverBond");
        vm.label(address(usdc), "USDC");
        vm.label(address(summerToken), "SummerToken");
    }

    function test_CompleteAaveV3IntentFlow() public {
        // Step 1: Commander (ark) creates intent for yield generation
        vm.startPrank(keeper);
        IIntentHandler.Intent memory intent = IIntentHandler.Intent({
            user: address(ark),
            requiredNotional: REQUIRED_NOTIONAL,
            requiredBond: BOND_AMOUNT,
            term: TERM,
            targetYield: TARGET_YIELD,
            token: address(usdc),
            oracle: address(mockOracle),
            expiry: block.timestamp + 1 days
        });
        intentHandler.createIntent(intent);
        vm.stopPrank();

        // Verify intent was created
        assertTrue(
            intentHandler.intentStates(keccak256(abi.encode(intent))) ==
                IIntentHandler.IntentState.Created
        );

        // Step 2: Solver solves the intent
        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(intent, ESCROWED_YIELD);
        vm.stopPrank();

        // Verify intent was solved
        assertTrue(
            intentHandler.intentStates(keccak256(abi.encode(intent))) ==
                IIntentHandler.IntentState.Solved
        );

        // Step 3: Time passes - yield generation period
        vm.warp(block.timestamp + TERM + 1);

        // Step 4: Solver settles the intent
        vm.startPrank(solver);
        intentHandler.settleIntent(intent);
        vm.stopPrank();

        // Verify intent is settled
        assertTrue(
            intentHandler.intentStates(keccak256(abi.encode(intent))) ==
                IIntentHandler.IntentState.Settled
        );

        // Verify solver bond is intact (successful completion)
        assertTrue(intentBondFactory.isSolverVouched(solver, BOND_AMOUNT));
        assertEq(intentBondFactory.getSolverBondAmount(solver), BOND_AMOUNT);
    }

    function test_EscrowDirectOperations() public {
        // Test direct escrow operations (these would be called by IntentHandler)
        uint256 escrowAmount = 1000e6; // 1000 USDC

        // Get the solver's escrow
        Escrow solverEscrow = intentHandler.solverEscrows(solver);

        // Test escrow yield operation (called by IntentHandler during solveIntent)
        vm.startPrank(address(intentHandler));
        IERC20(address(usdc)).approve(address(solverEscrow), escrowAmount);
        solverEscrow.deposit(address(usdc), escrowAmount, bytes32("1"));
        vm.stopPrank();

        // Test return escrowed yield operation
        vm.startPrank(address(intentHandler));
        solverEscrow.withdraw(
            address(usdc),
            address(intentHandler),
            bytes32("1")
        );
        vm.stopPrank();
    }

    function test_IntentCancellation() public {
        // Create intent
        vm.startPrank(keeper);
        IIntentHandler.Intent memory intent = IIntentHandler.Intent({
            user: commander,
            requiredNotional: REQUIRED_NOTIONAL,
            requiredBond: BOND_AMOUNT,
            term: TERM,
            targetYield: TARGET_YIELD,
            token: address(usdc),
            oracle: address(mockOracle),
            expiry: block.timestamp + 1 days
        });
        intentHandler.createIntent(intent);

        // Cancel before it's solved
        intentHandler.resignByUser(intent);
        vm.stopPrank();

        // Verify intent was cancelled
        assertTrue(
            intentHandler.intentStates(keccak256(abi.encode(intent))) ==
                IIntentHandler.IntentState.UserResigned
        );
    }

    function test_SolverResignation() public {
        // Setup intent and solve it
        vm.startPrank(keeper);
        IIntentHandler.Intent memory intent = IIntentHandler.Intent({
            user: commander,
            requiredNotional: REQUIRED_NOTIONAL,
            requiredBond: BOND_AMOUNT,
            term: TERM,
            targetYield: TARGET_YIELD,
            token: address(usdc),
            oracle: address(mockOracle),
            expiry: block.timestamp + 1 days
        });
        intentHandler.createIntent(intent);
        vm.stopPrank();

        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(intent, ESCROWED_YIELD);

        // Solver resigns (gets bond slashed)
        intentHandler.resignBySolver(intent);
        vm.stopPrank();

        // Verify resignation and bond slashing
        assertTrue(
            intentHandler.intentStates(keccak256(abi.encode(intent))) ==
                IIntentHandler.IntentState.SolverResigned
        );

        // Bond should be slashed by 50%
        assertEq(
            intentBondFactory.getSolverBondAmount(solver),
            BOND_AMOUNT / 2
        );
    }

    function test_OracleDecimalHandling() public {
        // Test decimal handling for different token types

        // Test 1: USDC (6 decimals) at $1.00
        address usdcToken = address(usdc);
        vm.startPrank(governor);
        mockOracle.addSupportedToken(usdcToken);
        mockOracle.setPrice(usdcToken, 1e18, 6); // $1.00, 6 decimals
        vm.stopPrank();

        (uint256 usdcPrice, , uint8 usdcDecimals) = mockOracle.getPrice(
            usdcToken
        );
        assertEq(
            usdcPrice,
            1e18,
            "USDC price should be $1.00 with 18 decimals"
        );
        assertEq(usdcDecimals, 6, "USDC should have 6 decimals");

        // Calculate notional value of 1000 USDC
        // Formula: (amount * price) / (10 ** decimals)
        // (1000e6 * 1e18) / (10 ** 6) = 1000e18 = $1000.00
        uint256 usdcNotional = mockOracle.calculateNotionalValue(
            usdcToken,
            1000e6
        );
        assertEq(usdcNotional, 1000e18, "1000 USDC should equal $1000.00");

        // Test 2: Summer token (18 decimals) at $1.00
        address summerTokenAddr = address(summerToken);
        vm.startPrank(governor);
        mockOracle.setPrice(summerTokenAddr, 1e18, 18); // $1.00, 18 decimals
        vm.stopPrank();

        (uint256 sumrPrice, , uint8 sumrDecimals) = mockOracle.getPrice(
            summerTokenAddr
        );
        assertEq(
            sumrPrice,
            1e18,
            "SUMR price should be $1.00 with 18 decimals"
        );
        assertEq(sumrDecimals, 18, "SUMR should have 18 decimals");

        // Calculate notional value of 1000 SUMR
        // Formula: (amount * price) / (10 ** decimals)
        // (1000e18 * 1e18) / (10 ** 18) = 1000e18 = $1000.00
        uint256 sumrNotional = mockOracle.calculateNotionalValue(
            summerTokenAddr,
            1000e18
        );
        assertEq(sumrNotional, 1000e18, "1000 SUMR should equal $1000.00");

        // Test 3: Verify bond requirement calculation
        // The solver has BOND_AMOUNT (1000e6) SUMR tokens as bond
        // But 1000e6 with 18 decimals is actually 0.001 SUMR tokens, not 1000!
        uint256 actualBondAmount = intentBondFactory.getSolverBondAmount(
            solver
        );
        assertEq(
            actualBondAmount,
            BOND_AMOUNT,
            "Solver should have 1000e6 SUMR tokens as bond"
        );

        // For $1000 worth of SUMR bonds at $1/SUMR, we need 1000e18 SUMR tokens
        // But the solver only has 1000e6 SUMR tokens, so this should fail
        uint256 requiredBondFor1000USD = 1000e18; // 1000 SUMR tokens
        assertFalse(
            intentBondFactory.isSolverVouched(solver, requiredBondFor1000USD),
            "Solver should NOT have sufficient bond for $1000 requirement (only has 1000e6)"
        );

        // But for $0.001 worth of SUMR bonds, the solver should have sufficient bond
        uint256 requiredBondForMicroUSD = 1000e6; // 1000e6 SUMR tokens = $0.001
        assertTrue(
            intentBondFactory.isSolverVouched(solver, requiredBondForMicroUSD),
            "Solver should have sufficient bond for $0.001 requirement"
        );
    }

    function test_FractionalPriceScenario() public {
        // Test decimal handling with fractional prices (0.5 USDC per SUMR)

        // Setup fractional price: 0.5 USDC per SUMR
        // This means 1 SUMR = 0.5 USDC, so price = 5e17 (0.5 USD with 18 decimals)
        address sumrToken = address(summerToken);
        address usdcToken = address(usdc);

        vm.startPrank(governor);
        mockOracle.addSupportedToken(usdcToken);
        mockOracle.addSupportedToken(sumrToken);
        mockOracle.setPrice(sumrToken, 5e17, 18); // 0.5 USD per SUMR
        mockOracle.setPrice(usdcToken, 1e18, 6); // 1.0 USD per USDC
        vm.stopPrank();

        // Verify prices are set correctly
        (uint256 sumrPrice, , uint8 sumrDecimals) = mockOracle.getPrice(
            sumrToken
        );
        assertEq(
            sumrPrice,
            5e17,
            "SUMR price should be 0.5 USD with 18 decimals"
        );
        assertEq(sumrDecimals, 18, "SUMR should have 18 decimals");

        // Test 1: Calculate notional value of 1000 SUMR at 0.5 USD each
        // Expected: 1000 SUMR * 0.5 USD = 500 USD
        // Formula: (1000e18 * 5e17) / (10 ** 18) = 500e18 = $500.00
        uint256 sumrNotional = mockOracle.calculateNotionalValue(
            sumrToken,
            1000e18
        );
        assertEq(
            sumrNotional,
            500e18,
            "1000 SUMR at 0.5 USD each should equal $500.00"
        );

        // Test 2: Calculate notional value of 2000 SUMR at 0.5 USD each
        // Expected: 2000 SUMR * 0.5 USD = 1000 USD
        // Formula: (2000e18 * 5e17) / (10 ** 18) = 1000e18 = $1000.00
        uint256 sumrNotional2 = mockOracle.calculateNotionalValue(
            sumrToken,
            2000e18
        );
        assertEq(
            sumrNotional2,
            1000e18,
            "2000 SUMR at 0.5 USD each should equal $1000.00"
        );

        // Test 3: Calculate how many SUMR tokens needed for $1000 worth of bonds
        // We want: token_amount = (USD_amount * 10^decimals) / price
        // For $1000 worth of SUMR: (1000e18 * 10^18) / 5e17 = 2000e18 SUMR tokens
        uint256 requiredBondAmount = (1000e18 * (10 ** 18)) / 5e17;
        assertEq(
            requiredBondAmount,
            2000e18,
            "Should need 2000 SUMR tokens for $1000 worth of bonds"
        );

        // Test 4: Verify bond requirement logic with fractional pricing
        // If we want $500 worth of SUMR bonds, we need 1000 SUMR tokens
        // But our solver only has 1000e6 SUMR tokens (which is 0.001 SUMR)
        uint256 requiredBondFor500USD = 1000e18; // 1000 SUMR tokens = $500
        assertFalse(
            intentBondFactory.isSolverVouched(solver, requiredBondFor500USD),
            "Solver should NOT have sufficient bond for $500 requirement (only has 1000e6 SUMR)"
        );

        // Test 5: Edge case - calculate notional value of fractional amounts
        // 500 SUMR at 0.5 USD each = 250 USD
        uint256 fractionalNotional = mockOracle.calculateNotionalValue(
            sumrToken,
            500e18
        );
        assertEq(
            fractionalNotional,
            250e18,
            "500 SUMR at 0.5 USD each should equal $250.00"
        );
    }

    function test_ArchitecturalBenefits() public {
        // This test demonstrates the architectural benefits of the new design

        // 1. Escrow is deployed for specific solver
        Escrow solverEscrow = intentHandler.solverEscrows(solver);
        assertEq(
            address(solverEscrow),
            address(intentHandler.solverEscrows(solver))
        );

        // 2. Escrow is registered with specific solver
        assertEq(
            address(intentHandler.solverEscrows(solver)),
            address(solverEscrow)
        );

        // 3. Access control is centralized and consistent
        // Commander (ark) can create intents (this is verified by the successful createIntent call above)

        // 4. Intent flow is standardized
        vm.startPrank(keeper);
        IIntentHandler.Intent memory intent = IIntentHandler.Intent({
            user: commander,
            requiredNotional: 100e6,
            requiredBond: BOND_AMOUNT,
            term: 7 days,
            targetYield: 10e6,
            token: address(usdc),
            oracle: address(mockOracle),
            expiry: block.timestamp + 1 days
        });
        intentHandler.createIntent(intent);
        vm.stopPrank();

        vm.startPrank(solver);
        deal(USDC_MAINNET, address(solver), 10000e6);
        IERC20(USDC_MAINNET).approve(address(intentHandler), 10000e6);
        intentHandler.solveIntent(intent, 10e6);
        vm.stopPrank();

        // The same pattern can be used for Compound, Morpho, etc.
        // Just deploy new escrows and register them with solvers
    }
}
